const { GoogleAuth } = require('google-auth-library');
const path = require('path');
const jwt = require('jsonwebtoken');
const fs = require('fs');

class GoogleWalletService {
  constructor() {
    this.credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

    // Resolve path if it's not absolute
    const fullPath = path.isAbsolute(this.credentialsPath)
      ? this.credentialsPath
      : path.join(__dirname, '../', this.credentialsPath);

    this.auth = new GoogleAuth({
      keyFile: fullPath,
      scopes: ['https://www.googleapis.com/auth/wallet_object.issuer']
    });

    // Leer el archivo para firmar JWTs manualmente
    try {
      this.credentials = JSON.parse(fs.readFileSync(fullPath, 'utf8'));
    } catch (e) {
      console.error('Error reading wallet credentials for JWT signing:', e);
    }
  }

  async getClient() {
    return await this.auth.getClient();
  }

  /**
   * Creates a GenericClass
   * @param {string} classId 
   * @param {Object} classData 
   * @returns {Object} response data
   */
  async createGenericClass(classId, classData) {
    const client = await this.getClient();

    // Check if the class already exists
    try {
      const getResponse = await client.request({
        url: `https://walletobjects.googleapis.com/walletobjects/v1/genericClass/${classId}`,
        method: 'GET'
      });
      console.log('Class already exists');
      return getResponse.data;
    } catch (e) {
      if (e.response && e.response.status !== 404) {
        console.error('Error fetching class:', e.response ? e.response.data : e);
        throw e;
      }
    }

    console.log('Creating new generic class');
    const response = await client.request({
      url: 'https://walletobjects.googleapis.com/walletobjects/v1/genericClass',
      method: 'POST',
      data: classData
    });

    return response.data;
  }

  /**
   * Creates a GenericObject
   * @param {string} objectId 
   * @param {Object} objectData 
   * @returns {Object} response data
   */
  async createGenericObject(objectId, objectData) {
    const client = await this.getClient();

    // Check if the object already exists
    try {
      const getResponse = await client.request({
        url: `https://walletobjects.googleapis.com/walletobjects/v1/genericObject/${objectId}`,
        method: 'GET'
      });
      console.log('Object already exists');
      return getResponse.data;
    } catch (e) {
      if (e.response && e.response.status !== 404) {
        console.error('Error fetching object:', e.response ? e.response.data : e);
        throw e;
      }
    }

    console.log('Creating new generic object');
    const response = await client.request({
      url: 'https://walletobjects.googleapis.com/walletobjects/v1/genericObject',
      method: 'POST',
      data: objectData
    });

    return response.data;
  }

  /**
   * Updates an existing GenericObject
   * @param {string} objectId 
   * @param {Object} objectData 
   * @returns {Object} response data
   */
  async updateGenericObject(objectId, objectData) {
    const client = await this.getClient();
    console.log(`Updating generic object: ${objectId}`);
    const response = await client.request({
      url: `https://walletobjects.googleapis.com/walletobjects/v1/genericObject/${objectId}`,
      method: 'PATCH',
      data: objectData
    });
    return response.data;
  }

  /**
   * Deletes a GenericObject
   * @param {string} objectId 
   * @returns {Object} response data
   */
  async deleteGenericObject(objectId) {
    const client = await this.getClient();
    console.log(`Deleting generic object: ${objectId}`);
    const response = await client.request({
      url: `https://walletobjects.googleapis.com/walletobjects/v1/genericObject/${objectId}`,
      method: 'DELETE'
    });
    return response.data;
  }

  /**
   * Genera un JWT firmado para el botón "Save to Google Wallet"
   * @param {Object} genericObject El objeto ya creado
   * @returns {string} URL completa de guardado
   */
  async createSaveToWalletUrl(genericObject) {
    if (!this.credentials || !this.credentials.private_key) {
      throw new Error('No se cargaron las credenciales necesarias para firmar el JWT');
    }

    const payload = {
      iss: this.credentials.client_email,
      aud: 'google',
      typ: 'savetowallet',
      iat: Math.floor(Date.now() / 1000),
      // No incluimos 'origins' para pruebas locales/móvil
      payload: {
        genericObjects: [genericObject]
      }
    };

    const token = jwt.sign(payload, this.credentials.private_key, { algorithm: 'RS256' });
    return `https://pay.google.com/gp/v/save/${token}`;
  }
}

module.exports = { GoogleWalletService };
