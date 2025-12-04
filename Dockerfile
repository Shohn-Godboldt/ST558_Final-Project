# Dockerfile for ST558 Final Project API

FROM rocker/r-ver:4.3.2

# Install system libraries
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages needed for the API
RUN R -e "install.packages(c('tidyverse','janitor','tidymodels','yardstick','plumber','rpart'), repos = 'https://cloud.r-project.org')"

# Set working directory inside the container
WORKDIR /app

# Copy project files into container
COPY api.R /app/
COPY diabetes_binary_health_indicators_BRFSS2015.csv /app/

# Expose the port that plumber will use
EXPOSE 8000

# Command to start the API when the container runs
CMD [\"R\", \"-e\", \"pr <- plumber::pr('api.R'); plumber::pr_run(pr, host='0.0.0.0', port=8000)\"]

