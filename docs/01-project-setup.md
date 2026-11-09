# Project Setup

This guide records the setup steps completed so far for the Azure AKS Terraform CI/CD project. It covers the local Flask application only. No Azure resources or deployment infrastructure are described here.

> Run the commands below in Windows PowerShell from the project folder, unless a step says otherwise.

## 1. Created the project folder in VS Code

**What we did:** Created the `aks-terraform-cicd` project folder and opened it in VS Code.

**Why:** The project folder keeps the application and its documentation together in one workspace.

**Command:** No terminal command was used; the folder was created and opened in VS Code.

**How we verified it:** The project folder was open in VS Code.

## 2. Created the `app` and `docs` folders

**What we did:** Added an `app` folder for the Flask application and a `docs` folder for project guides.

**Why:** Separating application files from documentation makes the project easier to navigate.

**Command:** No terminal command was used; both folders were created in VS Code.

**How we verified it:** Both `app` and `docs` appeared inside the project folder.

## 3. Created the Flask application files

**What we did:** Created `app/app.py` and `app/requirements.txt`. The Python file serves a welcome message at `/` and a JSON health response at `/health`. The requirements file specifies Flask.

**Why:** `app.py` contains the web application, while `requirements.txt` lists the Python package it needs.

**Files created:**

- `app/app.py`
- `app/requirements.txt`

**How we verified it:** The application started successfully in a later step, and both routes returned the expected responses when tested.

## 4. Created and activated the virtual environment

**What we did:** Created a Python virtual environment named `.venv` and activated it in Windows PowerShell.

**Why:** A virtual environment keeps this project's Python packages separate from other Python projects on the computer.

**Commands** (from the project folder):

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

**How we verified it:** The virtual environment was active in PowerShell before installing Flask.

## 5. Installed Flask 3.1.3

**What we did:** Installed the packages listed in the app's requirements file while the virtual environment was active. Flask 3.1.3 was installed.

**Why:** Flask provides the web framework used by the application.

**Command** (from the project folder):

```powershell
python -m pip install -r app\requirements.txt
```

**How we verified it:** The application started successfully using the environment where Flask was installed.

## 6. Started the application

**What we did:** Ran the Flask application from the project folder.

**Why:** Starting the local server makes the homepage and health endpoint available for testing.

**Command:**

```powershell
python app/app.py
```

**How we verified it:** The application started and responded to requests at the local address `127.0.0.1:5000`.

## 7. Tested the homepage and health endpoint

**What we did:** Opened both local URLs in a browser:

- `http://127.0.0.1:5000`
- `http://127.0.0.1:5000/health`

**Why:** Testing both routes confirms that the homepage and health check are reachable.

**How we verified it:** The homepage displayed `Welcome to Azure AKS Project`. The health endpoint returned JSON with status `healthy`.

## Troubleshooting

- **PowerShell does not recognize `python`:** Check that Python is installed and available in your `PATH`, then reopen PowerShell.
- **The virtual environment is not active:** From the project folder, run `.\.venv\Scripts\Activate.ps1` again.
- **PowerShell blocks activation:** Follow your organization's guidance for PowerShell script execution policies. Do not change the policy unless you understand and are authorized to do so.
- **Flask cannot be imported:** Activate `.venv`, then install the requirements with `python -m pip install -r app\requirements.txt`.
- **The browser cannot connect:** Confirm that the application is still running in PowerShell and that the URL uses port `5000`.
- **Port 5000 is already in use:** Stop the other local application using that port, then start this application again.

## Azure AKS Interview Questions

### 1. What is Azure Kubernetes Service (AKS)?

**Answer:** AKS is Azure's managed Kubernetes service. It helps teams run and manage containerized applications on Kubernetes without managing every part of the Kubernetes control plane themselves.

### 2. What is a Kubernetes pod?

**Answer:** A pod is the smallest deployable unit in Kubernetes. It contains one or more closely related containers that share network and storage resources.

### 3. Why might a team use CI/CD with AKS?

**Answer:** CI/CD can automate building and testing application changes, then deliver approved changes to an AKS environment consistently. The exact pipeline and deployment setup depend on the project.