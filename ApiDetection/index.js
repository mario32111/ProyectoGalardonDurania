const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const { spawn } = require('child_process');

const app = express();
const port = process.env.PORT || 3000;

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

app.post('/predict', upload.single('imagen'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No se subió ninguna imagen' });
  }

  const imagePath = req.file.path;
  
  // Ejecutar el script de Python
  const pythonProcess = spawn('python', ['predict.py', imagePath]);

  let dataString = '';
  let errorString = '';

  pythonProcess.stdout.on('data', (data) => {
    dataString += data.toString();
  });

  pythonProcess.stderr.on('data', (data) => {
    errorString += data.toString();
  });

  pythonProcess.on('close', (code) => {
    if (code !== 0) {
      console.error('Error del script de Python:', errorString);
      return res.status(500).json({ error: 'Error al procesar la imagen con el modelo YOLO', detalle: errorString });
    }

    try {
      // Parsear el JSON que devuelve el script de Python
      const jsonResult = JSON.parse(dataString.trim());
      
      // Combinar los resultados en la respuesta
      res.json({
        mensaje: 'Inferencia completada exitosamente',
        filename: req.file.filename,
        resultados: jsonResult
      });
    } catch (e) {
      console.error('Error al parsear JSON del script de Python:', e);
      console.error('Salida cruda:', dataString);
      res.status(500).json({ error: 'Respuesta inválida del modelo', salida_cruda: dataString });
    }
  });
});

app.listen(port, () => {
  console.log(`API escuchando en http://localhost:${port}`);
});
