# A sample set of Bicep for building and deploying an Azure Open AI Platform with AI Gateway

TLDR;

```
cd ./infra
az deployment sub create --location <location> --template-file ./main.bicep --parameters ./parameters.bicepparam
```

## TODO (working notes)

### Creating Indexes

To use APIm for creating an Index via AI Studio you need to open up the /ingestion endpoint which isn't in the Open API inferences file. 

AI Studio uses the end user identity, not a system identity to call AOAI. AOAI then calls back out to Azure Search, and AI Studio to perform the indexing tasks.

Provide Cog Services Open AI Contributor to AI Studio users who need to create Indexes
 - Cog Services User is not enough for the /ingestion endpoint

Provide Search Service Contributor to AI Studio who need to create Indexes
Provide Search Index Data Contributor to AI Studio who need to create Indexes



## Azure AI Studio notes

### If running from outside the private networks:

Enable access to Azure Open AI from your IP address

Enable access to Azure Search from your IP address
- Some flows from Azure AI Studio come via your browser

