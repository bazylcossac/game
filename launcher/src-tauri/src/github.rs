use crate::models::Release;
use reqwest::{blocking::Client, header, redirect::Policy};
use semver::Version;
use serde::Deserialize;
use std::time::Duration;

pub const REPOSITORY: &str = "bazylcossac/game";
pub type Result<T> = std::result::Result<T, String>;

#[derive(Deserialize)]
struct GitHubRelease {
    id: u64,
    tag_name: String,
    name: Option<String>,
    body: Option<String>,
    published_at: Option<String>,
    draft: bool,
    prerelease: bool,
    assets: Vec<Asset>,
}

#[derive(Deserialize)]
struct Asset {
    id: u64,
    name: String,
    size: u64,
    digest: Option<String>,
    state: String,
}

pub fn client() -> Result<Client> {
    Client::builder()
        .user_agent(concat!("CorpWars-Launcher/", env!("CARGO_PKG_VERSION")))
        .connect_timeout(Duration::from_secs(15))
        .timeout(Duration::from_secs(900))
        .redirect(Policy::custom(|attempt| {
            let host = attempt.url().host_str().unwrap_or("");
            if attempt.previous().len() > 8 {
                return attempt.error("Za dużo przekierowań");
            }
            if attempt.url().scheme() == "https"
                && matches!(
                    host,
                    "api.github.com"
                        | "github.com"
                        | "release-assets.githubusercontent.com"
                        | "objects.githubusercontent.com"
                )
            {
                attempt.follow()
            } else {
                attempt.error("Niedozwolone przekierowanie pobierania")
            }
        }))
        .build()
        .map_err(|e| format!("Nie można uruchomić pobierania: {e}"))
}

pub struct Catalog {
    pub releases: Vec<Release>,
    pub etag: Option<String>,
    pub unchanged: bool,
}

pub fn fetch(client: &Client, etag: Option<&str>) -> Result<Catalog> {
    let mut releases = Vec::new();
    let mut new_etag = None;
    for page in 1..=100 {
        let mut request = client
            .get(format!(
                "https://api.github.com/repos/{REPOSITORY}/releases?per_page=100&page={page}"
            ))
            .header(header::ACCEPT, "application/vnd.github+json")
            .header("X-GitHub-Api-Version", "2022-11-28")
            .timeout(Duration::from_secs(30));
        if page == 1 {
            if let Some(tag) = etag {
                request = request.header(header::IF_NONE_MATCH, tag);
            }
        }
        let response = request.send().map_err(|_| {
            "Nie można połączyć się z GitHub. Zainstalowana gra pozostaje dostępna.".to_string()
        })?;
        if response.status() == 304 {
            return Ok(Catalog {
                releases: Vec::new(),
                etag: etag.map(str::to_string),
                unchanged: true,
            });
        }
        if !response.status().is_success() {
            return Err(match response.status().as_u16() {
                403 | 429 => "GitHub ograniczył liczbę zapytań. Spróbuj ponownie później; obecna gra pozostaje dostępna.".into(),
                404 => "Repozytorium lub wydania nie są publicznie dostępne.".into(),
                code => format!("GitHub zwrócił błąd {code}. Spróbuj ponownie później."),
            });
        }
        if page == 1 {
            new_etag = response
                .headers()
                .get(header::ETAG)
                .and_then(|v| v.to_str().ok())
                .map(str::to_string);
        }
        let json: Vec<GitHubRelease> = response
            .json()
            .map_err(|e| format!("Niepoprawny katalog GitHub: {e}"))?;
        let last = json.len() < 100;
        // A first-page ETag does not validate changes on later pages.
        if page == 1 && !last {
            new_etag = None;
        }
        releases.extend(json.into_iter().filter_map(convert));
        if last {
            break;
        }
        if page == 100 {
            return Err("Katalog jest zbyt duży. Zaktualizuj launcher.".into());
        }
    }
    drop_channel_copy(&mut releases);
    releases.sort_by(|a, b| {
        a.testing.cmp(&b.testing).then_with(|| {
            let a_version = Version::parse(&a.version).ok();
            let b_version = Version::parse(&b.version).ok();
            b_version
                .cmp(&a_version)
                .then(b.published_at.cmp(&a.published_at))
        })
    });
    Ok(Catalog {
        releases,
        etag: new_etag,
        unchanged: false,
    })
}

/// The test channel "najnowsza" carries a copy of the newest panel build. When that build is in the
/// list on its own, the copy would only show it twice, so it goes.
fn drop_channel_copy(releases: &mut Vec<Release>) {
    let builds: Vec<String> = releases
        .iter()
        .filter(|r| r.tag.starts_with(PANEL_PREFIX))
        .map(|r| r.sha256.clone())
        .collect();
    releases.retain(|r| r.tag != CHANNEL || !builds.contains(&r.sha256));
}

/// The rolling test channel, and the tag prefix of every build ordered from the task panel.
const CHANNEL: &str = "najnowsza";
const PANEL_PREFIX: &str = "panel-";

fn convert(raw: GitHubRelease) -> Option<Release> {
    if raw.draft {
        return None;
    }
    // Test builds: the rolling channel and each build ordered from the panel, which GitHub keeps
    // as prereleases. Numbered prereleases (v1.2.0-beta) stay out.
    let testing =
        raw.tag_name == CHANNEL || (raw.prerelease && raw.tag_name.starts_with(PANEL_PREFIX));
    let version = raw
        .tag_name
        .strip_prefix('v')
        .unwrap_or(&raw.tag_name)
        .to_string();
    if !testing && (raw.prerelease || !Version::parse(&version).ok()?.pre.is_empty()) {
        return None;
    }
    // Explicit names keep launcher installers and source archives out of the game list.
    let asset = raw.assets.into_iter().find(|a| {
        matches!(
            a.name.as_str(),
            "MieczDawida-windows.exe" | "CorpWars-windows.exe"
        ) && a.state == "uploaded"
    })?;
    let sha256 = asset.digest?.strip_prefix("sha256:")?.to_ascii_lowercase();
    if sha256.len() != 64
        || !sha256.bytes().all(|x| x.is_ascii_hexdigit())
        || asset.size < 1024
        || asset.size > 2 * 1024 * 1024 * 1024
    {
        return None;
    }
    Some(Release {
        key: format!("{}:{}:{}", raw.id, asset.id, sha256),
        release_id: raw.id,
        asset_id: asset.id,
        tag: raw.tag_name,
        version: if testing { "test".into() } else { version },
        title: raw.name.unwrap_or_default(),
        notes: raw.body.unwrap_or_default(),
        published_at: raw.published_at?,
        sha256,
        size: asset.size,
        testing,
    })
}

pub fn target<'a>(selection: &str, releases: &'a [Release]) -> Option<&'a Release> {
    match selection {
        "stable" => releases.iter().find(|r| !r.testing),
        // Sorted newest first, so this is the latest test build.
        "testing" => releases.iter().find(|r| r.testing),
        value => value
            .strip_prefix("pin:")
            .and_then(|key| releases.iter().find(|r| r.key == key)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn raw(tag: &str, name: &str, digest: Option<&str>) -> GitHubRelease {
        GitHubRelease {
            id: 1,
            tag_name: tag.into(),
            name: None,
            body: None,
            published_at: Some("2026-11-10".into()),
            draft: false,
            prerelease: false,
            assets: vec![Asset {
                id: 2,
                name: name.into(),
                size: 2048,
                digest: digest.map(str::to_string),
                state: "uploaded".into(),
            }],
        }
    }
    #[test]
    fn separates_launcher_assets_and_requires_digest() {
        let digest = format!("sha256:{}", "a".repeat(64));
        assert!(convert(raw(
            "launcher-v0.1.0",
            "CorpWars-Launcher-Setup.exe",
            Some(&digest)
        ))
        .is_none());
        assert!(convert(raw("v0.12.0", "MieczDawida-windows.exe", None)).is_none());
        assert!(convert(raw("v0.12.0", "MieczDawida-windows.exe", Some(&digest))).is_some());
    }
    #[test]
    fn rejects_drafts_and_prereleases_except_named_testing_channel() {
        let digest = format!("sha256:{}", "b".repeat(64));
        let mut draft = raw("v0.13.0", "MieczDawida-windows.exe", Some(&digest));
        draft.draft = true;
        assert!(convert(draft).is_none());
        assert!(convert(raw(
            "v0.13.0-beta.1",
            "MieczDawida-windows.exe",
            Some(&digest)
        ))
        .is_none());
        let mut test = raw("najnowsza", "MieczDawida-windows.exe", Some(&digest));
        test.prerelease = true;
        assert!(convert(test).unwrap().testing);
    }
    #[test]
    fn panel_builds_are_test_builds_and_the_channel_copy_goes() {
        let digest = format!("sha256:{}", "d".repeat(64));
        let mut build = raw("panel-3d054663-d88b-49d5-a849-2a4ff3a17504", "CorpWars-windows.exe", Some(&digest));
        build.prerelease = true;
        build.id = 7;
        let build = convert(build).unwrap();
        assert!(build.testing && build.version == "test");
        let mut not_pre = raw("panel-x", "CorpWars-windows.exe", Some(&digest));
        not_pre.prerelease = false;
        assert!(convert(not_pre).is_none());
        let mut channel = raw("najnowsza", "CorpWars-windows.exe", Some(&digest));
        channel.prerelease = true;
        let channel = convert(channel).unwrap();
        let mut list = vec![channel.clone(), build.clone()];
        drop_channel_copy(&mut list);
        assert_eq!(list, vec![build.clone()]);
        let mut older = channel;
        older.sha256 = "e".repeat(64);
        let mut list = vec![older.clone(), build];
        drop_channel_copy(&mut list);
        assert_eq!(list.len(), 2, "a channel holding another build stays");
    }
    #[test]
    fn pin_matches_identity_instead_of_tag() {
        let digest = format!("sha256:{}", "c".repeat(64));
        let release = convert(raw("v0.12.0", "MieczDawida-windows.exe", Some(&digest))).unwrap();
        let pin = format!("pin:{}", release.key);
        assert!(target(&pin, &[release.clone()]).is_some());
        let mut replaced = release;
        replaced.key.push('x');
        assert!(target(&pin, &[replaced]).is_none());
    }
}
