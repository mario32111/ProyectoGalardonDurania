const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

// Asegurar que existe la carpeta uploads
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir);
  console.log('Carpeta uploads creada');
}

const app = express();
const port = process.env.PORT || 3002;

// Configurar multer para el manejo de archivos (imágenes)
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'uploads/');
  },
  filename: function (req, file, cb) {
    cb(null, Date.now() + path.extname(file.originalname));
  }
});

const upload = multer({ storage: storage });

app.use(cors());
app.use(express.json());

// Servir archivos estáticos si se desea ver la imagen subida (opcional)
app.use('/uploads', express.static(uploadsDir));

app.post('/predict', upload.single('imagen'), (req, res) => {
  if (!req.file) {
    console.log('[-] Solicitud sin imagen');
    return res.status(400).json({ error: 'No se subió ninguna imagen' });
  }

  const imagePath = path.resolve(req.file.path);
  console.log(`[+] Imagen recibida: ${req.file.filename}`);
  console.log(`[+] Ruta completa: ${imagePath}`);
  console.log(`[+] Iniciando script de Python...`);

  // Ejecutar el script de Python con ruta absoluta
  const scriptPath = path.join(__dirname, 'predict.py');
  const pythonProcess = spawn('python', [scriptPath, imagePath], {
    cwd: __dirname // Ejecutar desde el directorio del proyecto para que encuentre best.pt
  });

  let dataString = '';
  let errorString = '';

  // Si el proceso de Python no puede ni siquiera iniciar
  pythonProcess.on('error', (err) => {
    console.error('[ERROR] No se pudo iniciar Python:', err.message);
    return res.status(500).json({
      error: 'No se pudo ejecutar Python. ¿Está instalado y en el PATH?',
      detalle: err.message
    });
  });

  pythonProcess.stdout.on('data', (data) => {
    console.log(`[PYTHON stdout]: ${data.toString().trim()}`);
    dataString += data.toString();
  });

  pythonProcess.stderr.on('data', (data) => {
    console.log(`[PYTHON stderr]: ${data.toString().trim()}`);
    errorString += data.toString();
  });

  pythonProcess.on('close', (code) => {
    console.log(`[+] Python terminó con código: ${code}`);

    // Eliminar la imagen temporal después de procesarla
    fs.unlink(imagePath, (err) => {
      if (err) console.error(`[WARN] No se pudo eliminar ${imagePath}:`, err.message);
      else console.log(`[+] Imagen temporal eliminada: ${req.file.filename}`);
    });

    if (code !== 0) {
      console.error('[ERROR] Salida de error de Python:', errorString);
      return res.status(500).json({ error: 'Error al procesar la imagen con el modelo YOLO', detalle: errorString });
    }

    try {
      const jsonResult = JSON.parse(dataString.trim());
      console.log(`[+] Resultado:`, jsonResult);

      res.json({
        mensaje: 'Inferencia completada exitosamente',
        filename: req.file.filename,
        resultados: jsonResult
      });
    } catch (e) {
      console.error('[ERROR] No se pudo parsear JSON:', e.message);
      console.error('[ERROR] Salida cruda:', dataString);
      res.status(500).json({
        error: 'Respuesta inválida del modelo',
        salida_cruda: dataString,
        detalle_error: e.message
      });
    }
  });
});

// Manejador de errores global para devolver JSON siempre
app.use((err, req, res, next) => {
  console.error('Error detectado:', err);
  res.status(500).json({
    success: false,
    error: err.message || 'Error interno del servidor'
  });
});

app.listen(port, () => {
  console.log(`API de detección escuchando en http://localhost:${port}`);
});
