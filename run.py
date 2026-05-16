from pathlib import Path
from dotenv import load_dotenv

dotenv_path = Path(__file__).resolve().parent / '.env'
load_dotenv(dotenv_path=dotenv_path)

from app import create_app

app = create_app()

if __name__ == "__main__":
    app.run(debug=True, threaded=True, host="0.0.0.0", port=8000)
