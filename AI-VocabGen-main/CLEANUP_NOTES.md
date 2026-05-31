# Cleanup Notes

- Removed legacy table models from the SQLAlchemy import path.
- Removed the included SQLite file. Start the backend once to recreate a clean database.
- Removed the bundled `.venv` and Python cache files from the deliverable ZIP.
- Add Word now supports instant Arabic translation while typing.
- Saving a word stores: the word, Arabic meaning, English definition, and an example sentence.
- Home and Progress use real backend values, not hardcoded fake values.
- My Words opens word details with meaning, definition, examples, and SM2 info.

## Run after extracting

```bash
cd Back-End
pip install -r requirements.txt
python run_backend.py
```

If an old `vocabgen.db` exists, delete it before running the backend.
