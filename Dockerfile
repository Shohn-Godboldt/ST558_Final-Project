# Dockerfile for ST558 Final Project API
# Use rocker/tidyverse so tidyverse is already installed
FROM rocker/tidyverse:4.3.2

# Install extra R packages needed for the model and API
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('plumber','janitor','tidymodels','yardstick','rpart'), repos = 'https://cloud.r-project.org')"

# Set working directory inside the container
WORKDIR /app

# Copy project files into container
COPY api.R /app/api.R
COPY diabetes_binary_health_indicators_BRFSS2015.csv /app/diabetes_binary_health_indicators_BRFSS2015.csv

# Expose plumber port
EXPOSE 8000

# Start the plumber API when the container runs
CMD R -e \"pr <- plumber::pr('api.R'); plumber::pr_run(pr, host='0.0.0.0', port=8000)\"
