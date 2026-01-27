import { AzureOpenAI } from "openai";
import dotenv from "dotenv";

dotenv.config();

export const azureConfig = {
  endpoint: process.env.AZURE_OPENAI_ENDPOINT,
  apiKey: process.env.AZURE_OPENAI_API_KEY,
  apiVersion: process.env.AZURE_OPENAI_API_VERSION,
  deployment: process.env.AZURE_OPENAI_DEPLOYMENT_NAME,
  modelName: process.env.AZURE_OPENAI_MODEL_NAME
};

export function createAzureClient() {
  console.log('🛠️ Creando cliente Azure OpenAI...');
  
  if (!azureConfig.apiKey) {
    throw new Error("AZURE_OPENAI_API_KEY no está configurada");
  }

  if (!azureConfig.endpoint) {
    throw new Error("AZURE_OPENAI_ENDPOINT no está configurado");
  }

  return new AzureOpenAI({
    endpoint: azureConfig.endpoint,
    apiKey: azureConfig.apiKey,
    deployment: azureConfig.deployment,
    apiVersion: azureConfig.apiVersion
  });
}