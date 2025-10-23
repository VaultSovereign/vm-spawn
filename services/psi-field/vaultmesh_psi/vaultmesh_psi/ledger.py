import json, os

class JsonLedgerIO:
    def __init__(self, directory):
        self.directory = directory
        os.makedirs(directory, exist_ok=True)

    def write(self, name, records):
        path = os.path.join(self.directory, f"{name}.jsonl")
        with open(path, "w", encoding="utf-8") as f:
            for r in records:
                f.write(json.dumps(r) + "\n")
        return path
