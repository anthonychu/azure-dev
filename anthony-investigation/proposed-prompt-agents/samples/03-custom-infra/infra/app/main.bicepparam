using './main.bicep'

param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus2')
param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'dev')
