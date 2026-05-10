# Production-ready Dockerfile for PipelineForge app
FROM public.ecr.aws/lambda/python:3.11 as base

# Install system dependencies
RUN yum install -y gcc

# Set workdir
WORKDIR /var/task

# Copy requirements and install
COPY requirements.txt ./
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy app code
COPY app.py ./

# Set environment variables
ENV PORT=5000

# Use Lambda Runtime Interface Emulator for local testing
CMD ["app.handler"]

# For ECS, override CMD to run Flask
ENTRYPOINT ["python"]
CMD ["app.py"]
