# Docker for the Flask Application

This guide describes the Docker setup that currently exists in the `app` folder. The documented build and run commands are the commands used for this project; they are included here for reference and are not run while writing this guide.

## Why use Docker before deploying to AKS?

Docker packages the application and its Python dependencies into an image. This gives AKS a consistent unit to run, instead of relying on Python and Flask being installed directly on a machine. The image can be built and tested locally before moving on to a deployment workflow.

This project currently has a Flask application and a Dockerfile. This guide does not imply that an AKS cluster or deployment configuration has been created.

## Our Dockerfile

The Dockerfile is `app/Dockerfile`. Here is what each instruction does:

| Instruction | In simple English |
|---|---|
| `FROM python:3.11-slim` | Starts from the official Python 3.11 slim image. It provides Python while keeping the base image smaller than a full Python image. |
| `LABEL com.azure.containerizationassist.createdby="containerization-assist"` | Adds metadata identifying the tool associated with creating the Dockerfile. |
| `WORKDIR /app` | Sets `/app` as the working folder inside the image. Later copy and run instructions use this folder. |
| `ENV PYTHONDONTWRITEBYTECODE=1` | Tells Python not to write `.pyc` bytecode files. |
| `ENV PYTHONUNBUFFERED=1` | Makes Python send output promptly, which helps make application logs visible. These two variables are written together in the Dockerfile using a line continuation. |
| `COPY requirements.txt .` | Copies the dependency list from the build context into `/app` in the image. |
| `RUN pip install --no-cache-dir -r requirements.txt` | Installs Flask and Gunicorn from the requirements file. `--no-cache-dir` prevents pip from keeping its package download cache in the image. |
| `COPY app.py .` | Copies the Flask application code into `/app`. |
| `RUN useradd --create-home --uid 10001 appuser` | Creates a regular user named `appuser` with user ID 10001 and a home folder. |
| `USER appuser` | Runs the application as `appuser` rather than as the root user. |
| `EXPOSE 5000` | Documents that the application listens on container port 5000. This instruction does not publish the port to the host by itself. |
| `HEALTHCHECK ...` | Periodically asks the application’s `/health` endpoint if it is responding. The timing and check are explained below. |
| `CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]` | Sets the default command to start Gunicorn on all container network interfaces at port 5000. `app:app` means the `app` object in `app.py`. The JSON array is Docker's exec form. |

## Supporting files

- `app/requirements.txt` lists `Flask>=3.0,<4.0` and `gunicorn>=23.0,<24.0`. These ranges allow compatible releases while limiting each dependency to the stated major version.
- `app/.dockerignore` keeps unnecessary files out of the Docker build context. It excludes the virtual environment folders, Python bytecode and cache folders, `.git`, `.env` files, tool caches, and log files. This helps avoid copying local development files or environment files into the build context.
- `app/app.py` defines the homepage at `/` and the JSON health response at `/health`.

## Docker image and Docker container

- A **Docker image** is the packaged template built from the Dockerfile. In this project, `aks-flask-app:v1` is the image name and tag.
- A **Docker container** is a running instance created from an image. In this project, `aks-flask-container` is the container name.

The image can be used to create containers. A container runs the application process; the image itself is not a running application.

## Why Gunicorn instead of Flask's development server?

Flask's built-in server is intended for local development. The Dockerfile starts Gunicorn, a WSGI server intended to serve Python web applications, as the container's application process. It runs the Flask `app` object and listens on `0.0.0.0:5000`. This is a more appropriate server choice for a containerized deployment than Flask's development server.

## Build the image

The successful build command used for this project was:

```powershell
docker build -t aks-flask-app:v1 ./app
```

In simple terms, Docker uses `app` as the build context, reads its Dockerfile, and tags the resulting image as `aks-flask-app:v1`. The context includes the files available in `app` except those excluded by `.dockerignore`.

## Run the container and map its port

The run command used for this project was:

```powershell
docker run -d --name aks-flask-container -p 5000:5000 aks-flask-app:v1
```

- `-d` runs the container in the background.
- `--name aks-flask-container` gives the container a recognizable name.
- `-p 5000:5000` maps **host port 5000** to **container port 5000**. The first number is the port on your computer; the second is the port inside the container where Gunicorn listens.
- `aks-flask-app:v1` is the image to run.

The port mapping is what makes the container's web server reachable from the host at `http://127.0.0.1:5000`.

## Verify the application

Check that the container is running:

```powershell
docker ps
```

Look for `aks-flask-container` in the list. Its port information should include a mapping from host port `5000` to container port `5000`.

Then open these addresses in a browser:

- `http://127.0.0.1:5000` should display `Welcome to Azure AKS Project`.
- `http://127.0.0.1:5000/health` should return JSON with status `healthy`.

## Docker HEALTHCHECK

The Dockerfile defines a health check with a 30-second interval, a 3-second timeout, a 5-second start period, and 3 retries. It runs Python's standard HTTP client to request `http://127.0.0.1:5000/health` from inside the container. A successful response means the endpoint could be reached; a failed request is reported as an unsuccessful health check. Docker reports the container's health status, but the health check does not restart or repair a failing application by itself.

## Troubleshooting

**The container is not listed by `docker ps`:** It may have exited. List all containers and inspect its recent logs:

```powershell
docker ps -a
docker logs aks-flask-container
```

**The browser cannot connect:** Confirm the container is running and that port `5000` is published:

```powershell
docker ps
docker port aks-flask-container
```

**The image needs to be rebuilt after changing app files or dependencies:** Run the build command again. If a container with the same name already exists, remove that container first using the cleanup commands below.

**The health check is failing:** Check the application logs and confirm that `/health` responds when the container is running:

```powershell
docker logs aks-flask-container
```

## Cleanup

Stop and remove the named container:

```powershell
docker stop aks-flask-container
docker rm aks-flask-container
```

To also remove the local image after removing the container:

```powershell
docker rmi aks-flask-app:v1
```

These commands remove the container and image named above; they do not remove other containers or images.

## Docker Interview Questions

### 1. What is the difference between a Docker image and a container?

**Answer:** An image is a packaged template. A container is a running instance created from that template.

### 2. Why is Docker useful before deploying an application to AKS?

**Answer:** Docker packages the app and its dependencies together, giving AKS a consistent image to run.

### 3. What does `-p 5000:5000` do?

**Answer:** It maps port 5000 on the host computer to port 5000 inside the container, allowing a browser on the host to reach the app.

### 4. Why does this container use Gunicorn?

**Answer:** Gunicorn is a WSGI server used to serve the Flask application. Flask's built-in server is intended for development.

### 5. What does a Docker HEALTHCHECK do?

**Answer:** It periodically checks whether an application responds to a configured probe. Docker records the result as the container's health status.
