# A Solution Accelerator for deploying an Azure Open AI Platform based on Azure APIm AI Gateway


```
cd ./infra
az deployment sub create --location <location> --template-file ./main.bicep --parameters ./parameters.bicepparam
```

## What does it do?
The Solution Accelerator contains a set of Bicep templates to deploy an APIm AI Gateway Platform.

We deploy everything into a fully locked down Virtual Network using Entra Auth where possible.

The aim is to bake speed and safety into AI usage. All prompts and responses (streaming and non-streaming) are audited into a Cosmos database.

The Bicep templates deploy a Prompt Flow container demonstrating Entra auth via APIm.

They optionally deploy a VM (jumpbox) for testing the accelerator in a fully private environment, and demonstrate automating the deployment of Azure AI Foundry.

## Architecture Diagram

### (Working notes whilst building the accelerator)

#### Creating Indexes

To use APIm for creating an Index via AI Studio you need to open up the /ingestion endpoint which isn't in the Open API inference Open API definition. 

AI Studio uses the end user identity, not a system identity to call AOAI. AOAI then calls back out to Azure Search, and AI Studio to perform the indexing tasks.

Provide Cog Services Open AI Contributor to AI Studio users who need to create Indexes
 - Cog Services User is not enough for the /ingestion endpoint

Provide Search Service Contributor to AI Studio who need to create Indexes

Provide Search Index Data Contributor to AI Studio who need to create Indexes



### Azure AI Studio notes

##### If running from outside the private networks:

Enable access to Azure Open AI from your IP address

Enable access to Azure Search from your IP address
- Some flows from Azure AI Studio come via your browser

