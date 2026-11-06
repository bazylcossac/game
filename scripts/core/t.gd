class_name T
extends RefCounted
## The game's text is written in Polish in the code, and that text is the key. English comes from
## LangEn through Godot's translation server, so every Label and Button translates by itself.
## Text put together at run time goes through T.t first: T.t("POZIOM %d") % level.
## Text a server sends to players goes through T.pack instead, and the reader's T.t formats it.

const LANGUAGES := ["pl", "en"]
const NAMES := ["Polski", "English"]
const SEPARATOR := "\u001f"


static func setup(language: String) -> void:
	var table := Translation.new()
	table.locale = "en"
	for key: String in LangEn.TEXT:
		var value: String = LangEn.TEXT[key]
		table.add_message(key, value)
		# Names are often shown in capitals, so those forms have to match as well.
		if key.to_upper() != key:
			table.add_message(key.to_upper(), value.to_upper())
	TranslationServer.add_translation(table)
	apply(language)


static func apply(language: String) -> void:
	TranslationServer.set_locale(language if language in LANGUAGES else LANGUAGES[0])


## Text for another machine: the server cannot know the language each player reads.
static func pack(text: String, args: Array) -> String:
	var parts := PackedStringArray([text])
	for a: Variant in args:
		parts.append(str(a))
	return SEPARATOR.join(parts)


static func t(text: String) -> String:
	if not text.contains(SEPARATOR):
		return String(TranslationServer.translate(text))
	var parts := text.split(SEPARATOR)
	var args := []
	for i in range(1, parts.size()):
		args.append(parts[i].to_int() if parts[i].is_valid_int() else t(parts[i]))
	return t(parts[0]) % args
