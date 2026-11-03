---
name: registering-hex-vocabulary
description: Teach Hex (dictation) the product, project, and tool names in the prompts typed into Claude Code since the last run, each with the spellings a Japanese transcript shows for it. Never people or credentials. Made for an unattended daily run.
argument-hint: "[--since 30d]"
disable-model-invocation: true
allowed-tools:
  - Bash(python3:*)
---

# Registering Hex Vocabulary

Hex spells a name right only when its vocabulary holds the term and the
spellings a transcript shows instead of it. The prompts typed into Claude
Code are where those names appear in writing, so each run reads the prompts
since the last run, decides which tokens are names, and registers them. The
run is unattended: decide from the contexts, ask nothing, and report at the
end.

## Extract

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/hex-vocabulary.py" extract $ARGUMENTS
```

The window runs from the saved `last_run` to now (seven days on the first
run); `--since 30d` backfills. Each candidate carries `kind` (latin or
katakana), how many prompts and sessions it appeared in, the other casings
seen (`variants`), and up to three `contexts` — the prompt text around it.
Terms Hex already holds, their spellings, and terms an earlier run ignored
are already gone, and so are the shapes the script can recognise as a
credential or a personal identifier: e-mail addresses, @mentions, logins
ending in digits, API tokens, JWTs, values after `token:` or `password=`,
phone numbers, long random strings.

`vocabulary_checked: false` means Hex could not be asked for its list, so
the adds would fail the same way: stop and report the warning the script
printed.

## Judge

What leaves this skill is the vocabulary Hex holds, the ignore list on
disk, and the report. People and secrets go in none of them: a person's
name in any script (a romanised surname, a GitHub login, a Slack handle),
a credential the script did not catch (a password, a short key, a
hostname that embeds an account), an account or customer identifier, an
address. Such a candidate gets no verdict and is not quoted; it simply
goes unmentioned.

Every other candidate gets exactly one verdict:

- add — a name the user says aloud and Hex has to spell: product, service,
  company, team, project, repository, tool, library, model, protocol.
  Register the canonical spelling, whatever casing the prompt used
  (Zscaler, SonarQube, pnpm). A name split across candidates (Open + CTI)
  is one add with the full name.
- spelling of a term Hex already holds — a candidate that is a mishearing
  of a known term (Lotion for Notion, ソナーj for SonarJS, ミーテール for
  MiiTel): add with the known term as `term` and the candidate as its
  spelling. `hex vocabulary add` appends spellings to an existing term.
- ignore — a general word in any language (コメント, テスト, flag,
  approve), an identifier, a file or branch name, a command, a flag, an
  environment variable, a status word, a one-off typo. Ignored terms are
  never proposed again, so ignore only what will never be a name.
- neither — too little context to tell. Leave it out of both lists; it
  returns the next time it is typed.

`sounds_like` holds one to four spellings per add: the katakana reading a
Japanese Whisper transcript produces (ジースケーラー), the split or
misspelt Latin form seen in `variants` or `contexts` (Z Scaler, Militel),
never the term itself. The entries `hex vocabulary list` already shows are
the register to match. A spelling cannot contain a comma.

## Apply

Always run it, with empty lists if nothing qualified: it advances the
window.

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/hex-vocabulary.py" apply <<'EOF'
{
  "add": [
    {"term": "Zscaler", "sounds_like": ["ジースケーラー", "Z Scaler"]},
    {"term": "Notion", "sounds_like": ["Lotion"]},
    {"term": "pinact", "sounds_like": ["ピナクト"]}
  ],
  "ignore": ["コメント", "flag", "develop"]
}
EOF
```

When `failed` is not empty, the window and the ignore list did not move:
report the error (Hex not running, not installed) so the next run reads the
same prompts again.

## Report

One line per term added — term and spellings; `changed: false` means Hex
already had all of it — then the count ignored and the window read. No contexts, no candidates left unmentioned, nothing
else.
