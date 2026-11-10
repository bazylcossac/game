use crate::{
    github::{self, Result},
    models::*,
};
use fs2::FileExt;
use sha2::{Digest, Sha256};
use std::{
    fs::{self, File, OpenOptions},
    io::{Read, Seek, SeekFrom, Write},
    path::{Path, PathBuf},
    process::{Child, Command},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
    thread,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

const GAME_FILE: &str = "MieczDawida-windows.exe";

pub struct Engine {
    root: PathBuf,
    state: Mutex<DiskState>,
    progress: Mutex<Progress>,
    error: Mutex<Option<String>>,
    client: reqwest::blocking::Client,
    busy: AtomicBool,
    checking: AtomicBool,
    cancelled: AtomicBool,
    paused: AtomicBool,
    healthy: AtomicBool,
    online: AtomicBool,
    game: Mutex<Option<Child>>,
    operation: Mutex<()>,
    _lock: File,
}

fn io_error(error: impl std::fmt::Display) -> String {
    format!("Nie można zapisać plików launchera: {error}")
}
fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

pub fn reject_link(path: &Path) -> Result<()> {
    if let Ok(meta) = fs::symlink_metadata(path) {
        #[cfg(windows)]
        {
            use std::os::windows::fs::MetadataExt;
            if meta.file_attributes() & 0x400 != 0 {
                return Err(
                    "Katalog instalacji zawiera przekierowanie. Użyj zwykłego katalogu.".into(),
                );
            }
        }
        if meta.file_type().is_symlink() {
            return Err("Niedozwolony link w katalogu instalacji.".into());
        }
    }
    Ok(())
}

fn read_json<T: serde::de::DeserializeOwned>(path: &Path) -> Result<T> {
    reject_link(path)?;
    let file = File::open(path).map_err(io_error)?;
    if file.metadata().map_err(io_error)?.len() > 8 * 1024 * 1024 {
        return Err("Metadane launchera są zbyt duże.".into());
    }
    serde_json::from_reader(file).map_err(|e| format!("Niepoprawne metadane instalacji: {e}"))
}

fn replace(source: &Path, destination: &Path) -> Result<()> {
    reject_link(source)?;
    reject_link(destination)?;
    #[cfg(windows)]
    {
        use std::os::windows::ffi::OsStrExt;
        use windows_sys::Win32::Storage::FileSystem::{
            MoveFileExW, ReplaceFileW, MOVEFILE_WRITE_THROUGH,
        };
        let from: Vec<u16> = source.as_os_str().encode_wide().chain(Some(0)).collect();
        let to: Vec<u16> = destination
            .as_os_str()
            .encode_wide()
            .chain(Some(0))
            .collect();
        let success = unsafe {
            if destination.exists() {
                ReplaceFileW(
                    to.as_ptr(),
                    from.as_ptr(),
                    std::ptr::null(),
                    0,
                    std::ptr::null(),
                    std::ptr::null(),
                )
            } else {
                MoveFileExW(from.as_ptr(), to.as_ptr(), MOVEFILE_WRITE_THROUGH)
            }
        };
        if success == 0 {
            return Err(format!(
                "Nie można zastąpić pliku. Zamknij grę i spróbuj ponownie. Windows: {}",
                std::io::Error::last_os_error()
            ));
        }
        Ok(())
    }
    #[cfg(not(windows))]
    {
        fs::rename(source, destination).map_err(io_error)
    }
}

fn save_json<T: serde::Serialize>(path: &Path, value: &T) -> Result<()> {
    let temporary = path.with_extension("writing");
    reject_link(&temporary)?;
    reject_link(path)?;
    let mut file = File::create(&temporary).map_err(io_error)?;
    serde_json::to_writer_pretty(&mut file, value).map_err(io_error)?;
    file.sync_all().map_err(io_error)?;
    drop(file);
    replace(&temporary, path)
}

fn verify(path: &Path, release: &Release) -> Result<()> {
    reject_link(path)?;
    let mut file = File::open(path)
        .map_err(|_| "Brak pliku gry. Pobierz wybrane wydanie ponownie.".to_string())?;
    if file.metadata().map_err(io_error)?.len() != release.size {
        return Err("Plik gry ma nieprawidłowy rozmiar. Pobierz go ponownie.".into());
    }
    let mut hash = Sha256::new();
    let mut buffer = [0u8; 128 * 1024];
    loop {
        let count = file.read(&mut buffer).map_err(io_error)?;
        if count == 0 {
            break;
        }
        hash.update(&buffer[..count]);
    }
    if format!("{:x}", hash.finalize()) != release.sha256 {
        return Err("Plik nie przeszedł weryfikacji SHA-256. Pobierz go ponownie.".into());
    }
    file.seek(SeekFrom::Start(0)).map_err(io_error)?;
    let mut dos = [0u8; 64];
    file.read_exact(&mut dos).map_err(io_error)?;
    if &dos[..2] != b"MZ" {
        return Err("Pobrany plik nie jest programem Windows.".into());
    }
    let offset = u32::from_le_bytes(dos[60..64].try_into().unwrap()) as u64;
    if offset < 64 || offset > release.size.saturating_sub(26) {
        return Err("Niepoprawny nagłówek pliku Windows.".into());
    }
    file.seek(SeekFrom::Start(offset)).map_err(io_error)?;
    let mut pe = [0u8; 26];
    file.read_exact(&mut pe).map_err(io_error)?;
    if &pe[..4] != b"PE\0\0"
        || u16::from_le_bytes([pe[4], pe[5]]) != 0x8664
        || u16::from_le_bytes([pe[24], pe[25]]) != 0x20b
    {
        return Err("Paczka nie jest grą Windows x64.".into());
    }
    Ok(())
}

impl Engine {
    pub fn new(root: PathBuf) -> Result<Arc<Self>> {
        // Only fixed paths beneath this root are ever modified; no asset-supplied filenames.
        for path in [
            &root,
            &root.join("game"),
            &root.join("state"),
            &root.join("updates"),
        ] {
            reject_link(path)?;
            fs::create_dir_all(path).map_err(io_error)?;
        }
        let lock_path = root.join("state/launcher.lock");
        reject_link(&lock_path)?;
        let lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(lock_path)
            .map_err(io_error)?;
        lock.try_lock_exclusive()
            .map_err(|_| "Launcher już działa. Otwórz jego istniejące okno.".to_string())?;
        let state_path = root.join("state/installed.json");
        let state = if state_path.exists() {
            read_json(&state_path)?
        } else {
            DiskState::default()
        };
        let engine = Arc::new(Self {
            root,
            state: Mutex::new(state),
            progress: Mutex::new(Progress::default()),
            error: Mutex::new(None),
            client: github::client()?,
            busy: AtomicBool::new(false),
            checking: AtomicBool::new(false),
            cancelled: AtomicBool::new(false),
            paused: AtomicBool::new(false),
            healthy: AtomicBool::new(false),
            online: AtomicBool::new(false),
            game: Mutex::new(None),
            operation: Mutex::new(()),
            _lock: lock,
        });
        if let Err(error) = engine.recover() {
            *engine.error.lock().unwrap() = Some(error);
        }
        engine.check_health();
        Ok(engine)
    }

    fn game_path(&self) -> PathBuf {
        self.root.join("game").join(GAME_FILE)
    }
    fn pending_path(&self) -> PathBuf {
        self.root.join("updates/game.download")
    }
    fn journal_path(&self) -> PathBuf {
        self.root.join("state/transaction.json")
    }
    fn persist(&self, state: &DiskState) -> Result<()> {
        save_json(&self.root.join("state/installed.json"), state)
    }

    fn validate_paths(&self) -> Result<()> {
        for path in [
            &self.root,
            &self.root.join("game"),
            &self.root.join("state"),
            &self.root.join("updates"),
            &self.game_path(),
            &self.pending_path(),
            &self.journal_path(),
        ] {
            reject_link(path)?;
        }
        Ok(())
    }

    fn check_health(&self) {
        let installed = self.state.lock().unwrap().installed.clone();
        self.healthy.store(
            installed
                .as_ref()
                .is_some_and(|r| verify(&self.game_path(), r).is_ok()),
            Ordering::SeqCst,
        );
    }

    fn file_locked(&self) -> bool {
        if !self.game_path().exists() {
            return false;
        }
        #[cfg(windows)]
        {
            use std::os::windows::fs::OpenOptionsExt;
            OpenOptions::new()
                .read(true)
                .write(true)
                .share_mode(0)
                .open(self.game_path())
                .is_err()
        }
        #[cfg(not(windows))]
        {
            false
        }
    }

    pub fn game_running(&self) -> bool {
        let mut game = self.game.lock().unwrap();
        if let Some(child) = game.as_mut() {
            match child.try_wait() {
                Ok(Some(_)) => {
                    *game = None;
                }
                _ => return true,
            }
        }
        self.file_locked()
    }

    pub fn snapshot(&self) -> Snapshot {
        Snapshot {
            state: self.state.lock().unwrap().clone(),
            progress: self.progress.lock().unwrap().clone(),
            healthy: self.healthy.load(Ordering::SeqCst),
            busy: self.busy.load(Ordering::SeqCst),
            paused: self.paused.load(Ordering::SeqCst),
            game_running: self.game_running(),
            install_path: self.game_path().parent().unwrap().to_string_lossy().into(),
            error: self.error.lock().unwrap().clone(),
            online: self.online.load(Ordering::SeqCst),
            launcher_version: env!("CARGO_PKG_VERSION").into(),
        }
    }

    pub fn refresh(&self) -> Result<Snapshot> {
        if self.checking.swap(true, Ordering::SeqCst) {
            return Ok(self.snapshot());
        }
        let etag = self.state.lock().unwrap().etag.clone();
        let result = github::fetch(&self.client, etag.as_deref());
        self.checking.store(false, Ordering::SeqCst);
        match result {
            Ok(catalog) => {
                let mut state = self.state.lock().unwrap();
                let mut next = state.clone();
                if !catalog.unchanged {
                    next.releases = catalog.releases;
                    next.etag = catalog.etag;
                }
                next.checked_at = Some(now());
                self.persist(&next)?;
                *state = next;
                self.online.store(true, Ordering::SeqCst);
                *self.error.lock().unwrap() = None;
            }
            Err(error) => {
                self.online.store(false, Ordering::SeqCst);
                *self.error.lock().unwrap() = Some(error);
            }
        }
        Ok(self.snapshot())
    }

    pub fn preferences(&self, value: Preferences) -> Result<Snapshot> {
        if self.busy.load(Ordering::SeqCst) {
            return Err("Poczekaj na zakończenie aktualizacji.".into());
        }
        let mut state = self.state.lock().unwrap();
        if value.selection != state.preferences.selection
            && value.selection != "stable"
            && value.selection != "testing"
            && !state
                .releases
                .iter()
                .any(|r| value.selection == format!("pin:{}", r.key))
        {
            return Err("Wybrane wydanie nie jest dostępne. Odśwież katalog.".into());
        }
        let mut next = state.clone();
        next.preferences = value;
        self.persist(&next)?;
        *state = next;
        drop(state);
        Ok(self.snapshot())
    }

    pub fn start(self: &Arc<Self>, key: String, selection: String) -> Result<Snapshot> {
        let _operation = self.operation.lock().unwrap();
        if self.busy.swap(true, Ordering::SeqCst) {
            return Err("Aktualizacja już trwa.".into());
        }
        let state = self.state.lock().unwrap();
        let release = state.releases.iter().find(|r| r.key == key).cloned();
        let allowed = github::target(&selection, &state.releases).is_some_and(|r| r.key == key);
        drop(state);
        let Some(release) = release.filter(|_| allowed) else {
            self.busy.store(false, Ordering::SeqCst);
            return Err("Wybrane wydanie zmieniło się lub zniknęło. Odśwież katalog.".into());
        };
        self.cancelled.store(false, Ordering::SeqCst);
        self.paused.store(false, Ordering::SeqCst);
        *self.progress.lock().unwrap() = Progress {
            phase: "download".into(),
            total: release.size,
            target: Some(release.clone()),
            message: "Przygotowanie pobierania".into(),
            downloaded: 0,
        };
        let engine = Arc::clone(self);
        thread::spawn(move || {
            let result = engine.install(&release, &selection);
            if let Err(error) = result {
                let mut progress = engine.progress.lock().unwrap();
                progress.phase = if engine.cancelled.load(Ordering::SeqCst) {
                    "cancelled"
                } else {
                    "error"
                }
                .into();
                progress.message = error;
            }
            engine.check_health();
            engine.busy.store(false, Ordering::SeqCst);
        });
        Ok(self.snapshot())
    }

    fn control_point(&self) -> Result<()> {
        loop {
            if self.cancelled.load(Ordering::SeqCst) {
                return Err("Anulowano pobieranie. Obecna wersja pozostała bez zmian.".into());
            }
            if !self.paused.load(Ordering::SeqCst) {
                return Ok(());
            }
            thread::sleep(Duration::from_millis(100));
        }
    }

    fn install(&self, release: &Release, selection: &str) -> Result<()> {
        self.validate_paths()?;
        self.recover()?;
        if self
            .state
            .lock()
            .unwrap()
            .installed
            .as_ref()
            .is_some_and(|r| r.key == release.key)
            && verify(&self.game_path(), release).is_ok()
        {
            self.finish(release, selection)?;
            return Ok(());
        }
        let free = fs2::available_space(&self.root).map_err(io_error)?;
        if free < release.size + 32 * 1024 * 1024 {
            return Err(format!("Za mało miejsca. Potrzebujesz co najmniej {} MiB wolnego miejsca na dysku instalacji.", (release.size+32*1024*1024).div_ceil(1048576)));
        }
        let pending = self.pending_path();
        let transfer = (|| {
            let mut response = self
                .client
                .get(format!(
                    "https://api.github.com/repos/{}/releases/assets/{}",
                    github::REPOSITORY,
                    release.asset_id
                ))
                .header(reqwest::header::ACCEPT, "application/octet-stream")
                .header("X-GitHub-Api-Version", "2022-11-28")
                .send()
                .map_err(|_| {
                    "Nie udało się pobrać pliku. Sprawdź połączenie i spróbuj ponownie.".to_string()
                })?;
            if !response.status().is_success() {
                return Err(format!(
                    "Pobranie nie powiodło się (HTTP {}). Odśwież listę wydań.",
                    response.status().as_u16()
                ));
            }
            let mut file = File::create(&pending).map_err(io_error)?;
            let mut downloaded = 0u64;
            // Bounded handoff keeps cancellation responsive even if the next network
            // read stalls. Only this installer thread writes the pending file.
            let (sender, receiver) = std::sync::mpsc::sync_channel::<Result<Vec<u8>>>(2);
            thread::spawn(move || {
                let mut buffer = [0u8; 128 * 1024];
                loop {
                    match response.read(&mut buffer) {
                        Ok(count) => {
                            if sender.send(Ok(buffer[..count].to_vec())).is_err() || count == 0 {
                                break;
                            }
                        }
                        Err(_) => {
                            let _ = sender
                                .send(Err("Przerwano połączenie. Pobierz paczkę ponownie.".into()));
                            break;
                        }
                    }
                }
            });
            loop {
                self.control_point()?;
                let chunk = match receiver.recv_timeout(Duration::from_millis(200)) {
                    Ok(result) => result?,
                    Err(std::sync::mpsc::RecvTimeoutError::Timeout) => continue,
                    Err(_) => return Err("Przerwano pobieranie. Spróbuj ponownie.".into()),
                };
                if chunk.is_empty() {
                    break;
                }
                downloaded += chunk.len() as u64;
                if downloaded > release.size {
                    return Err(
                        "Serwer zwrócił plik większy niż zadeklarowany. Pobranie odrzucono.".into(),
                    );
                }
                file.write_all(&chunk).map_err(io_error)?;
                let mut p = self.progress.lock().unwrap();
                p.downloaded = downloaded;
                p.message = "Pobieranie pliku gry".into();
            }
            file.sync_all().map_err(io_error)?;
            drop(file);
            self.progress.lock().unwrap().phase = "verify".into();
            self.control_point()?;
            verify(&pending, release)?;
            Ok(())
        })();
        if let Err(error) = transfer {
            let _ = fs::remove_file(&pending);
            return Err(error);
        }
        self.progress.lock().unwrap().phase = "waiting".into();
        while self.game_running() {
            self.progress.lock().unwrap().message="Zamknij grę, aby dokończyć aktualizację. Jeśli gra jest zamknięta, sprawdź blokadę pliku przez inny program.".into();
            if let Err(error) = self.control_point() {
                let _ = fs::remove_file(&pending);
                return Err(error);
            }
            thread::sleep(Duration::from_millis(400));
        }
        if let Err(error) = self.control_point() {
            let _ = fs::remove_file(&pending);
            return Err(error);
        }
        let _operation = self.operation.lock().unwrap();
        self.validate_paths()?;
        let transaction = Transaction {
            release: release.clone(),
            selection: selection.into(),
        };
        save_json(&self.journal_path(), &transaction)?;
        self.progress.lock().unwrap().phase = "install".into();
        self.healthy.store(false, Ordering::SeqCst);
        replace(&pending, &self.game_path())?;
        verify(&self.game_path(), release)?;
        self.finish(release, selection)
    }

    fn finish(&self, release: &Release, selection: &str) -> Result<()> {
        let mut state = self.state.lock().unwrap();
        let mut next = state.clone();
        next.installed = Some(release.clone());
        next.preferences.selection = selection.into();
        self.persist(&next)?;
        *state = next;
        drop(state);
        self.cleanup()?;
        self.healthy.store(true, Ordering::SeqCst);
        *self.error.lock().unwrap() = None;
        let mut progress = self.progress.lock().unwrap();
        progress.phase = "done".into();
        progress.downloaded = release.size;
        progress.message =
            "Gotowe. Pozostała jedna zainstalowana wersja. Zapisy i ustawienia zachowane.".into();
        Ok(())
    }

    fn cleanup(&self) -> Result<()> {
        for path in [self.pending_path(), self.journal_path()] {
            reject_link(&path)?;
            if path.exists() {
                fs::remove_file(path).map_err(io_error)?;
            }
        }
        Ok(())
    }

    fn recover(&self) -> Result<()> {
        self.validate_paths()?;
        if !self.journal_path().exists() {
            // Interrupted downloads are not installations and are restarted from zero.
            if self.pending_path().exists() {
                fs::remove_file(self.pending_path()).map_err(io_error)?;
            }
            return Ok(());
        }
        let tx: Transaction = read_json(&self.journal_path())?;
        if verify(&self.game_path(), &tx.release).is_ok() {
            return self.finish(&tx.release, &tx.selection);
        }
        if verify(&self.pending_path(), &tx.release).is_ok() {
            if self.game_running() {
                return Err("Przerwana aktualizacja czeka na zamknięcie gry. Zamknij grę i ponów instalację.".into());
            }
            replace(&self.pending_path(), &self.game_path())?;
            verify(&self.game_path(), &tx.release)?;
            return self.finish(&tx.release, &tx.selection);
        }
        // Neither file is the verified new build. Keep a valid old build, otherwise request repair.
        self.cleanup()?;
        Err("Poprzednia aktualizacja została przerwana. Pobierz wybraną wersję ponownie.".into())
    }

    pub fn cancel(&self) -> Result<Snapshot> {
        let phase = self.progress.lock().unwrap().phase.clone();
        if phase == "install" {
            return Err("Trwa podmiana pliku. Poczekaj na zakończenie.".into());
        }
        self.cancelled.store(true, Ordering::SeqCst);
        self.paused.store(false, Ordering::SeqCst);
        Ok(self.snapshot())
    }

    pub fn pause(&self) -> Result<Snapshot> {
        if self.progress.lock().unwrap().phase != "download" {
            return Err("Można wstrzymać tylko pobieranie.".into());
        }
        let was_paused = self.paused.fetch_xor(true, Ordering::SeqCst);
        self.progress.lock().unwrap().message = if was_paused {
            "Pobieranie wznowione"
        } else {
            "Pobieranie wstrzymane"
        }
        .into();
        Ok(self.snapshot())
    }

    pub fn launch(&self) -> Result<Snapshot> {
        let _operation = self.operation.lock().unwrap();
        if self.busy.load(Ordering::SeqCst) {
            return Err("Poczekaj na zakończenie aktualizacji.".into());
        }
        if self.game_running() {
            return Err("Gra już działa.".into());
        }
        let installed = self
            .state
            .lock()
            .unwrap()
            .installed
            .clone()
            .ok_or("Najpierw zainstaluj grę.")?;
        if let Err(error) = verify(&self.game_path(), &installed) {
            self.healthy.store(false, Ordering::SeqCst);
            return Err(error);
        }
        let child = Command::new(self.game_path())
            .current_dir(self.root.join("game"))
            .spawn()
            .map_err(|e| format!("Nie można uruchomić gry: {e}"))?;
        *self.game.lock().unwrap() = Some(child);
        Ok(self.snapshot())
    }

    pub fn verify_installed(&self) -> Result<Snapshot> {
        if self.busy.load(Ordering::SeqCst) {
            return Err("Poczekaj na zakończenie aktualizacji.".into());
        }
        self.check_health();
        if !self.healthy.load(Ordering::SeqCst) {
            return Err("Plik gry wymaga naprawy. Pobierz wybrane wydanie ponownie.".into());
        }
        Ok(self.snapshot())
    }

    #[cfg(test)]
    fn wait_for_job(&self) {
        let start = std::time::Instant::now();
        while self.busy.load(Ordering::SeqCst) {
            assert!(start.elapsed() < Duration::from_secs(900), "job timeout");
            thread::sleep(Duration::from_millis(100));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn fixture(seed: u8) -> (Vec<u8>, Release) {
        let mut bytes = vec![seed; 2048];
        bytes[..2].copy_from_slice(b"MZ");
        bytes[60..64].copy_from_slice(&64u32.to_le_bytes());
        bytes[64..68].copy_from_slice(b"PE\0\0");
        bytes[68..70].copy_from_slice(&0x8664u16.to_le_bytes());
        bytes[88..90].copy_from_slice(&0x20bu16.to_le_bytes());
        let hash = format!("{:x}", Sha256::digest(&bytes));
        let release = Release {
            key: hash.clone(),
            release_id: 1,
            asset_id: seed as u64,
            tag: format!("v0.{seed}.0"),
            version: format!("0.{seed}.0"),
            title: String::new(),
            notes: String::new(),
            published_at: String::new(),
            sha256: hash,
            size: bytes.len() as u64,
            testing: false,
        };
        (bytes, release)
    }
    #[test]
    fn checks_hash_size_and_architecture() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("game");
        let (mut bytes, r) = fixture(1);
        fs::write(&file, &bytes).unwrap();
        assert!(verify(&file, &r).is_ok());
        bytes[100] ^= 1;
        fs::write(&file, &bytes).unwrap();
        assert!(verify(&file, &r).is_err());
        bytes.truncate(80);
        fs::write(&file, &bytes).unwrap();
        assert!(verify(&file, &r).is_err());
    }
    #[test]
    fn recovery_finishes_pending_replacement_and_keeps_one_executable() {
        let dir = tempfile::tempdir().unwrap();
        let e = Engine::new(dir.path().to_path_buf()).unwrap();
        let (old, old_r) = fixture(1);
        let (new, new_r) = fixture(2);
        fs::write(e.game_path(), old).unwrap();
        e.finish(&old_r, "stable").unwrap();
        fs::write(e.pending_path(), new).unwrap();
        save_json(
            &e.journal_path(),
            &Transaction {
                release: new_r.clone(),
                selection: format!("pin:{}", new_r.key),
            },
        )
        .unwrap();
        drop(e);
        let e = Engine::new(dir.path().to_path_buf()).unwrap();
        assert_eq!(e.snapshot().state.installed.unwrap().key, new_r.key);
        assert!(!e.pending_path().exists());
        assert!(!e.journal_path().exists());
        assert_eq!(fs::read_dir(dir.path().join("game")).unwrap().count(), 1);
    }
    #[test]
    fn recovery_reconciles_replaced_executable_before_state_write() {
        let dir = tempfile::tempdir().unwrap();
        let e = Engine::new(dir.path().to_path_buf()).unwrap();
        let (bytes, r) = fixture(3);
        fs::write(e.game_path(), bytes).unwrap();
        save_json(
            &e.journal_path(),
            &Transaction {
                release: r.clone(),
                selection: "stable".into(),
            },
        )
        .unwrap();
        drop(e);
        let e = Engine::new(dir.path().to_path_buf()).unwrap();
        assert_eq!(e.snapshot().state.installed.unwrap().key, r.key);
        assert!(e.snapshot().healthy);
    }
    #[test]
    fn corrupt_pending_file_does_not_remove_the_old_game_or_saves() {
        let dir = tempfile::tempdir().unwrap();
        let e = Engine::new(dir.path().to_path_buf()).unwrap();
        let (old, old_r) = fixture(1);
        let (_, new_r) = fixture(2);
        fs::write(e.game_path(), &old).unwrap();
        e.finish(&old_r, "stable").unwrap();
        let saves = dir.path().join("player-save.txt");
        fs::write(&saves, "keep").unwrap();
        fs::write(e.pending_path(), "bad").unwrap();
        save_json(
            &e.journal_path(),
            &Transaction {
                release: new_r,
                selection: "stable".into(),
            },
        )
        .unwrap();
        drop(e);
        let e = Engine::new(dir.path().to_path_buf()).unwrap();
        assert!(e.snapshot().healthy);
        assert_eq!(fs::read(e.game_path()).unwrap(), old);
        assert_eq!(fs::read_to_string(saves).unwrap(), "keep");
    }
    #[test]
    fn second_process_cannot_own_installation() {
        let dir = tempfile::tempdir().unwrap();
        let _e = Engine::new(dir.path().to_path_buf()).unwrap();
        assert!(Engine::new(dir.path().to_path_buf()).is_err());
    }
    #[test]
    fn unjournaled_partial_download_is_removed_on_restart() {
        let dir = tempfile::tempdir().unwrap();
        let e = Engine::new(dir.path().to_path_buf()).unwrap();
        fs::write(e.pending_path(), "part").unwrap();
        drop(e);
        let e = Engine::new(dir.path().to_path_buf()).unwrap();
        assert!(!e.pending_path().exists());
        assert!(e.snapshot().state.installed.is_none());
    }
    #[test]
    #[ignore = "Downloads real public game assets and tests replacing two versions in a temporary directory"]
    fn live_github_install_and_downgrade() {
        let dir = tempfile::tempdir().unwrap();
        let e = Engine::new(dir.path().to_path_buf()).unwrap();
        e.refresh().unwrap();
        let releases = e.snapshot().state.releases;
        let stable: Vec<_> = releases.into_iter().filter(|r| !r.testing).collect();
        assert!(stable.len() >= 2);
        e.start(stable[0].key.clone(), "stable".into()).unwrap();
        e.wait_for_job();
        assert!(e.snapshot().healthy, "{}", e.snapshot().progress.message);
        assert_eq!(e.snapshot().state.installed.unwrap().key, stable[0].key);
        e.start(stable[1].key.clone(), format!("pin:{}", stable[1].key))
            .unwrap();
        e.wait_for_job();
        assert!(e.snapshot().healthy, "{}", e.snapshot().progress.message);
        assert_eq!(e.snapshot().state.installed.unwrap().key, stable[1].key);
        assert_eq!(fs::read_dir(dir.path().join("game")).unwrap().count(), 1);
        assert!(!e.pending_path().exists());
        assert!(!e.journal_path().exists());
        drop(e);
        let e = Engine::new(dir.path().to_path_buf()).unwrap();
        assert_eq!(
            e.snapshot().state.preferences.selection,
            format!("pin:{}", stable[1].key)
        );
    }
}
