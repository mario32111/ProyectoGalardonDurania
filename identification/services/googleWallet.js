const { GoogleAuth } = require('google-auth-library');

class GoogleWalletService {
  constructor() {
    this.credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    this.auth = new GoogleAuth({
      keyFile: this.credentialsPath,
      scopes: ['https://www.googleapis.com/auth/wallet_object.issuer']
    });
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
}

module.exports = { GoogleWalletService };
