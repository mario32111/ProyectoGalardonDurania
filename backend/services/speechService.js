const OpenAI = require('openai');
const fs = require('fs');
const path = require('path');

class SpeechService {
    constructor() {
        // Usamos Groq (gratis) con el modelo Whisper para transcripción
        this.client = null;
    }

    /**
     * Inicializa el cliente Groq (lazy init para no fallar al arrancar si no hay key)
     */
    getClient() {
        if (!this.client) {
            const apiKey = process.env.GROQ_API_KEY;
            if (!apiKey) {
                throw new Error(
                    'GROQ_API_KEY no está configurada en .env. ' +
                    'Obtén una gratis en https://console.groq.com'
                );
            }
            this.client = new OpenAI({
                apiKey: apiKey,
                baseURL: 'https://api.groq.com/openai/v1'
            });
        }
        return this.client;
    }

    /**
     * Transcribir un archivo de audio a texto usando Whisper vía Groq
     * Soporta: WAV, MP3, OGG, WebM, MP4, MPEG, MPGA, M4A
     * 
     * @param {string} filePath - Ruta absoluta al archivo de audio
     * @param {string} language - Código de idioma (default: 'es' para español)
     * @returns {Promise<{text: string, segments: Array}>}
     */
    async transcribeFile(filePath, language = 'es') {
        const client = this.getClient();

        console.log('🎙️ Transcribiendo audio con Whisper...', path.basename(filePath));

        const transcription = await client.audio.transcriptions.create({
            file: fs.createReadStream(filePath),
            model: 'whisper-large-v3-turbo', // Modelo más rápido de Groq
            language: language,
            response_format: 'verbose_json', // Incluye timestamps y segmentos
            temperature: 0.0
        });

        console.log('✅ Transcripción completada:', transcription.text?.substring(0, 80) + '...');

        // Extraer segmentos si están disponibles
        const segments = transcription.segments?.map(seg => ({
            text: seg.text,
            start: seg.start,
            end: seg.end
        })) || [];

        return {
            text: transcription.text || '',
            segments: segments,
            language: transcription.language || language,
            duration: transcription.duration || null
        };
    }

    /**
     * Transcribir audio desde un Buffer (útil para WebSocket)
     * Guarda temporalmente el buffer como archivo WAV y lo transcribe
     * 
     * @param {Buffer} audioBuffer - Buffer de audio
     * @param {string} format - Formato del audio ('wav', 'webm', 'mp3', 'ogg')
     * @param {string} language - Código de idioma
     * @returns {Promise<{text: string, segments: Array}>}
     */
    async transcribeBuffer(audioBuffer, format = 'wav', language = 'es') {
        // Crear archivo temporal
        const tmpDir = path.join(__dirname, '..', 'uploads');
        if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir, { recursive: true });

        const tmpFile = path.join(tmpDir, `ws_audio_${Date.now()}.${format}`);

        try {
            fs.writeFileSync(tmpFile, audioBuffer);
            const result = await this.transcribeFile(tmpFile, language);
            return result;
        } finally {
            // Limpiar archivo temporal
            if (fs.existsSync(tmpFile)) {
                fs.unlink(tmpFile, () => { });
            }
        }
    }
}

module.exports = new SpeechService();
