# Interview Simulator Backend (Flask)

## Setup (Windows)

```bash
py -3.11 -m venv venv
.\venv\Scripts\Activate.ps1
python.exe -m pip install --upgrade pip
pip install --use-deprecated=legacy-resolver -r requirements.txt


updating database

flask db init
flask db migrate -m "initial migration"
flask db upgrade


npx repomix --ignore "**/venv/**,**/node_modules/**,**/.git/**,**/models/**,**/*.onnx,**/*.pth,**/__pycache__/**"

```
