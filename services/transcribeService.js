const axios = require('axios');
const fs = require('fs');
const FormData = require('form-data');
const config = require('../config');

class transcribeService {

  constructor() {
    // Inicializamos la configuración UNA sola vez
    this.baseUrl = config.aiApiUrl;
    // this.apiKey = config.aiApiKey; // Si la necesitas
    // Configuración base de Axios para no repetirla
    this.client = axios.create({
      baseURL: this.baseUrl,
      timeout: 10000, // 20 segundos máximo de espera
    });

    this.context = '';
  }

  /**
   * Envía un archivo de audio a la API externa
   * @param {string} filePath - Ruta del archivo .wav
   * @param {Object} options - Opciones de contexto { useContext: boolean, updateContext: boolean }
   * @returns {Promise<Object>} Respuesta de la API
   */
  async enviarAudio(filePath, options = {}) {
    const { useContext = true, updateContext = true } = options;

    try {
      const form = new FormData();
      form.append('file', fs.createReadStream(filePath));

      // Si necesitas enviar metadatos adicionales
      // Solo enviamos el contexto si useContext es true
      const promptToSend = useContext ? (this.context || '') : '';
      form.append('prompt', promptToSend);

      console.log(`🚀 [AiService] Enviando: ${filePath} | Contexto: ${useContext ? 'SI' : 'NO'}`);

      // Usamos la instancia pre-configurada de axios
      // Nota: getHeaders() es necesario cuando usas form-data manual en Node
      const response = await this.client.post('/trans?language=es', form, {
        headers: {
          ...form.getHeaders()
        }
      });

      console.log('🤖 [AiService] Respuesta:', response.data);

      // Solo actualizamos el contexto si updateContext es true
      if (updateContext) {
        this.context += " " + response.data.texto;
      }

      return response.data;

    } catch (error) {
      // Manejo de errores robusto
      if (error.response) {
        console.error(`❌ Error API (${error.response.status}):`, error.response.data);
      } else {
        console.error(`❌ Error de conexión:`, error.message);
      }
      // Opcional: Podrías guardar el error en un log o base de datos
      return null;
    }
  }

  async resetContext() {
    this.context = '';
  }
}

// --- TRUCO PRO ---
// Exportamos "new AiService()" para que actúe como Singleton.
// Así, todos los archivos que hagan require de esto compartirán la misma instancia.
module.exports = new transcribeService();