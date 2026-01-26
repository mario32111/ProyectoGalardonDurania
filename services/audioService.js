const fs = require('fs');
const path = require('path');

const RECORDINGS_DIR = path.join(__dirname, '..', 'recordings');
if (!fs.existsSync(RECORDINGS_DIR)) {
  fs.mkdirSync(RECORDINGS_DIR);
}

/**
 * --- TABLA DE DECODIFICACIÓN MU-LAW A PCM LINEAL ---
 * Esta tabla convierte los bytes comprimidos de telefonía (mu-law)
 * a audio de alta calidad de 16 bits (PCM).
 */
const muLawToPcmMap = new Int16Array(256);
for (let i = 0; i < 256; i++) {
    let input = ~i;
    let sign = (input & 0x80) ? -1 : 1;
    let exponent = (input >> 4) & 0x07;
    let mantissa = input & 0x0F;
    let sample = ((mantissa << 3) + 132) << exponent;
    muLawToPcmMap[i] = sign * (sample - 132);
}

/**
 * Función optimizada para guardar WAV claro
 */
function saveWavFile(mulawBuffer, filePath) {
    try {
        // 1. Convertir Mu-Law (8-bit) a PCM (16-bit)
        const pcmBuffer = Buffer.alloc(mulawBuffer.length * 2);
        
        for (let i = 0; i < mulawBuffer.length; i++) {
            const pcmVal = muLawToPcmMap[mulawBuffer[i]];
            pcmBuffer.writeInt16LE(pcmVal, i * 2);
        }

        // 2. Crear el Encabezado WAV (Header)
        const header = Buffer.alloc(44);
        const dataLength = pcmBuffer.length;
        const fileSize = 36 + dataLength;
        const sampleRate = 8000;
        const numChannels = 1;
        const bitsPerSample = 16;
        const byteRate = sampleRate * numChannels * (bitsPerSample / 8);
        const blockAlign = numChannels * (bitsPerSample / 8);

        header.write('RIFF', 0);
        header.writeUInt32LE(fileSize, 4);
        header.write('WAVE', 8);
        header.write('fmt ', 12);
        header.writeUInt32LE(16, 16);
        header.writeUInt16LE(1, 20);
        header.writeUInt16LE(numChannels, 22);
        header.writeUInt32LE(sampleRate, 24);
        header.writeUInt32LE(byteRate, 28);
        header.writeUInt16LE(blockAlign, 32);
        header.writeUInt16LE(bitsPerSample, 34);
        header.write('data', 36);
        header.writeUInt32LE(dataLength, 40);

        const finalWav = Buffer.concat([header, pcmBuffer]);

        fs.writeFileSync(filePath, finalWav);
        console.log(`📁 Audio CLARO guardado: ${filePath} (Tamaño: ${finalWav.length} bytes)`);

    } catch (error) {
        console.error(`❌ Error al guardar WAV:`, error);
    }
}

module.exports = {
    saveWavFile,
    RECORDINGS_DIR
};
