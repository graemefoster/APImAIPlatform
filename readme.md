# TODO after setup

## Creating Indexes

Can't use APIm as the openai definition doesn't include the /ingestion endpoint. You'll need to temporarily change the Connection endpoint for the AOAI connection to do this. TODO - maybe add both in.

AI Studio uses the end user identity, not a system identity to call AOAI. AOAI then calls back out to Azure Search, and AI Studio to perform the indexing tasks.

Provide Cog Services Open AI Contributor to AI Studio users who need to create Indexes
 - Cog Services User is not enough for the /ingestion endpoint

Provide Search Service Contributor to AI Studio who need to create Indexes
Provide Search Index Data Contributor to AI Studio who need to create Indexes



## If running from outside the private networks:

Enable access to Azure Open AI from your IP address

Enable access to Azure Search from your IP address

