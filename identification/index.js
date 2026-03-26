require('dotenv').config();
const express = require('express');
const { GoogleWalletService } = require('./services/googleWallet');

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

const walletService = new GoogleWalletService();
const createdCredentials = []; // Array temporal para guardar las credenciales creadas

// Rutas principales con interfaz básica
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Google Wallet API</title>
      <style>
        body { font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f8f9fa; margin: 0; padding: 40px 20px; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
        .container { width: 100%; max-width: 500px; background: white; border-radius: 20px; padding: 40px; box-shadow: 0 8px 24px rgba(0,0,0,0.04); text-align: center; }
        h1 { color: #202124; margin-top: 0; margin-bottom: 10px; font-size: 1.8rem; }
        p { color: #5f6368; margin-bottom: 30px; }
        ul { list-style: none; padding: 0; display: flex; flex-direction: column; gap: 12px; }
        li a { display: block; padding: 16px; background: #f8f9fa; border: 1px solid #e8eaed; border-radius: 12px; color: #202124; text-decoration: none; font-weight: 500; transition: all 0.2s; }
        li a:hover { background: #f1f3f4; border-color: #dadce0; transform: translateY(-1px); }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Bienvenido a Google Wallet API</h1>
        <p>Selecciona una opción para continuar:</p>
        <ul>
          <li><a href="/create">Crear ID Ganadero (Prueba)</a></li>
          <li><a href="/view">Ver mis credenciales</a></li>
        </ul>
      </div>
    </body>
    </html>
  `);
});

app.get('/create', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Crear Credencial</title>
      <style>
        body { font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f8f9fa; margin: 0; padding: 40px 20px; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
        .container { width: 100%; max-width: 500px; background: white; border-radius: 20px; padding: 40px; box-shadow: 0 8px 24px rgba(0,0,0,0.04); text-align: center; }
        h1 { color: #202124; margin-top: 0; margin-bottom: 10px; font-size: 1.8rem; }
        p { color: #5f6368; margin-bottom: 30px; line-height: 1.5; }
        .btn { display: inline-block; padding: 14px 28px; background-color: #0f4a3e; color: white; text-decoration: none; border-radius: 10px; font-weight: 600; border: none; cursor: pointer; font-size: 1rem; width: 100%; box-sizing: border-box; transition: all 0.2s; }
        .btn:hover { background-color: #0b362d; transform: translateY(-1px); }
        .btn-back { display: block; margin-top: 20px; color: #5f6368; text-decoration: none; font-weight: 500; }
        .btn-back:hover { color: #202124; text-decoration: underline; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Crear ID Ganadero</h1>
        <p>Haz clic en el botón inferior para generar una nueva credencial de prueba y agregarla a tu Google Wallet.</p>
        <form action="/api/wallet/class" method="POST">
          <button type="submit" class="btn">Generar Credencial de Prueba</button>
        </form>
        <a href="/" class="btn-back">Cancelar y volver</a>
      </div>
    </body>
    </html>
  `);
});

app.get('/view', (req, res) => {
  let credentialsHtml = '<p style="color: #666;">No se han creado credenciales en esta sesión.</p>';
  
  if (createdCredentials.length > 0) {
    credentialsHtml = '<div style="display: flex; flex-direction: column; gap: 24px; align-items: center;">';
    createdCredentials.forEach(cred => {
      credentialsHtml += `
        <div style="background-color: #0f4a3e; color: white; border-radius: 24px; padding: 24px; box-shadow: 0 10px 24px rgba(0,0,0,0.2); font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; position: relative; overflow: hidden; width: 100%; max-width: 380px; box-sizing: border-box;">
          
          <!-- Header -->
          <div style="display: flex; align-items: center; gap: 16px; margin-bottom: 16px;">
            <img src="${cred.logoUrl}" alt="Logo" style="width: 64px; height: 64px; border-radius: 50%; border: 3px solid #e0dfd5; object-fit: cover;">
            <span style="font-size: 1.5rem; font-weight: 500;">${cred.cardTitle}</span>
          </div>
          
          <div style="height: 1px; background-color: rgba(255,255,255,0.2); margin: 16px 0;"></div>
          
          <!-- Main Title -->
          <div style="font-size: 1.7rem; font-weight: 500; margin-bottom: 24px;">Asociación ganadera</div>
          
          <div style="height: 1px; background-color: rgba(255,255,255,0.2); margin: 16px 0;"></div>
          
          <!-- Details Grid -->
          <div style="display: flex; justify-content: space-between; margin-bottom: 24px;">
            <div>
              <div style="font-size: 0.85rem; margin-bottom: 8px;">Nombre</div>
              <div style="font-size: 1.1rem;">${cred.headerName}</div>
            </div>
            <div>
              <div style="font-size: 0.85rem; margin-bottom: 8px;">Clave UPP</div>
              <div style="font-size: 1.1rem;">13218654165</div>
            </div>
          </div>
          
          <div style="height: 1px; background-color: rgba(255,255,255,0.2); margin: 16px 0 24px 0;"></div>
          
          <!-- Barcode -->
          <div style="background-color: white; padding: 16px; border-radius: 8px; width: fit-content; margin: 0 auto 24px auto;">
            <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${cred.barcodeValue}" alt="QR Code" style="display: block; width: 150px; height: 150px;">
          </div>
          
          <!-- Actions -->
          <div style="display: flex; gap: 12px; justify-content: center;">
            <a href="/edit/${cred.id}" style="flex: 1; text-align: center; padding: 10px; background: rgba(255,255,255,0.15); border: 1px solid rgba(255,255,255,0.3); border-radius: 8px; color: white; text-decoration: none; font-size: 0.9rem; font-weight: 500; transition: all 0.2s;">Editar</a>
            <form action="/api/wallet/delete/${cred.id}" method="POST" style="flex: 1; display: contents;">
              <button type="submit" style="flex: 1; padding: 10px; background: rgba(255,59,48,0.2); border: 1px solid rgba(255,59,48,0.4); border-radius: 8px; color: #ff3b30; cursor: pointer; font-size: 0.9rem; font-weight: 500; transition: all 0.2s;" onclick="return confirm('¿Estás seguro de eliminar esta credencial?')">Eliminar</button>
            </form>
          </div>
          
        </div>`;
    });
    credentialsHtml += '</div>';
  }

  res.send(`
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Ver Credenciales</title>
      <style>
        body {
          font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
          background-color: #f8f9fa;
          margin: 0;
          padding: 40px 20px;
          min-height: 100vh;
          display: flex;
          justify-content: center;
        }
        .container {
          width: 100%;
          max-width: 600px;
          background: white;
          border-radius: 20px;
          padding: 40px;
          box-shadow: 0 8px 24px rgba(0,0,0,0.04);
        }
        h1 {
          color: #202124;
          margin-top: 0;
          margin-bottom: 30px;
          font-size: 1.8rem;
          text-align: center;
        }
        .btn-back {
          display: block;
          width: max-content;
          margin: 40px auto 0;
          padding: 12px 24px;
          background-color: #f1f3f4;
          color: #3c4043;
          text-decoration: none;
          border-radius: 8px;
          font-weight: 600;
          transition: all 0.2s ease;
        }
        .btn-back:hover {
          background-color: #e8eaed;
          transform: translateY(-1px);
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Mis Credenciales</h1>
        ${credentialsHtml}
        <a href="/" class="btn-back">← Volver al inicio</a>
      </div>
    </body>
    </html>
  `);
});

// Example route to generate a Generic class and object in Google Wallet
app.get('/edit/:id', (req, res) => {
  const cred = createdCredentials.find(c => c.id === req.params.id);
  if (!cred) return res.redirect('/view');

  res.send(`
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Editar Credencial</title>
      <style>
        body { font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f8f9fa; margin: 0; padding: 40px 20px; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
        .container { width: 100%; max-width: 500px; background: white; border-radius: 20px; padding: 40px; box-shadow: 0 8px 24px rgba(0,0,0,0.04); }
        h1 { color: #202124; margin-top: 0; margin-bottom: 30px; font-size: 1.8rem; text-align: center; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 8px; font-weight: 600; color: #3c4043; }
        input { width: 100%; padding: 12px; border: 1px solid #dadce0; border-radius: 8px; box-sizing: border-box; font-size: 1rem; }
        .btn { display: inline-block; padding: 14px 28px; background-color: #0f4a3e; color: white; text-decoration: none; border-radius: 10px; font-weight: 600; border: none; cursor: pointer; font-size: 1rem; width: 100%; box-sizing: border-box; transition: all 0.2s; }
        .btn:hover { background-color: #0b362d; transform: translateY(-1px); }
        .btn-back { display: block; margin-top: 20px; color: #5f6368; text-decoration: none; font-weight: 500; text-align: center; }
        .btn-back:hover { color: #202124; text-decoration: underline; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Editar ID Ganadero</h1>
        <form action="/api/wallet/update/${cred.id}" method="POST">
          <div class="form-group">
            <label for="headerName">Nombre del Ganadero</label>
            <input type="text" id="headerName" name="headerName" value="${cred.headerName}" required>
          </div>
          <button type="submit" class="btn">Guardar Cambios</button>
        </form>
        <a href="/view" class="btn-back">Cancelar</a>
      </div>
    </body>
    </html>
  `);
});

app.use(express.urlencoded({ extended: true }));

app.post('/api/wallet/update/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { headerName } = req.body;
    
    // 1. Find the credential
    const index = createdCredentials.findIndex(c => c.id === id);
    if (index === -1) throw new Error('Credencial no encontrada localmente');

    // 2. Update Google Wallet Object
    const updateData = {
      "header": { "defaultValue": { "language": "es", "value": headerName } }
    };

    await walletService.updateGenericObject(id, updateData);

    // 3. Update local array
    createdCredentials[index].headerName = headerName;

    res.redirect('/view');
  } catch (error) {
    console.error('Error updating generic credential:', error);
    res.status(500).send(`<p>Error al actualizar la credencial: ${error.message}</p><a href="/view">Volver</a>`);
  }
});

app.post('/api/wallet/delete/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // 1. Delete from Google Wallet
    try {
      await walletService.deleteGenericObject(id);
    } catch (e) {
      console.warn('Error deleting from Google Wallet (might not exist):', e.message);
    }

    // 2. Remove from local array
    const index = createdCredentials.findIndex(c => c.id === id);
    if (index !== -1) {
      createdCredentials.splice(index, 1);
    }

    res.redirect('/view');
  } catch (error) {
    console.error('Error deleting generic credential:', error);
    res.status(500).send(`<p>Error al eliminar la credencial: ${error.message}</p><a href="/view">Volver</a>`);
  }
});

// Example route to generate a Generic class and object in Google Wallet
app.post('/api/wallet/class', async (req, res) => {
  try {
    const defaultIssuerId = process.env.GOOGLE_ISSUER_ID;
    
    // Generar un ID único usando la fecha actual para poder crear varios
    const uniqueId = Date.now();
    const defaultClassName = `${defaultIssuerId}.test_generic_class_${uniqueId}`;
    const defaultObjectId = `${defaultIssuerId}.test_generic_object_${uniqueId}`;

    // 1. Create the Generic Class first
    const classData = {
      id: defaultClassName,
      // Mínimos datos requeridos para GenericClass (puede variar según tu caso)
      issuerName: 'ID Digital Universitaria',
    };
    
    await walletService.createGenericClass(defaultClassName, classData);

    // 2. Create the Generic Object linked to the Class
    const genericObject = {
      "id": defaultObjectId,
      "classId": defaultClassName,
      "genericType": "GENERIC_TYPE_UNSPECIFIED",
      "hexBackgroundColor": "#0f4a3e",
      "cardTitle": { "defaultValue": { "language": "es", "value": "ID Ganadero" } },
      "header": { "defaultValue": { "language": "es", "value": "Juan Pérez" } },
      "barcode": { "type": "QR_CODE", "value": `USER_ID_${uniqueId}` },
      "heroImage": { "sourceUri": { "uri": "https://ideogram.ai/assets/image/balanced/response/rlGqkkWISAqji08xC9q0DA@2k" } },
      "textModulesData": [
        {
          "id": "clave_upp",
          "header": "Clave UPP",
          "body": "13218654165"
        }
      ]
    };

    const createdObject = await walletService.createGenericObject(defaultObjectId, genericObject);
    
    // Guardamos la credencial creada para poder verla en /view
    createdCredentials.push({
      id: genericObject.id,
      cardTitle: genericObject.cardTitle.defaultValue.value,
      headerName: genericObject.header.defaultValue.value,
      logoUrl: genericObject.heroImage.sourceUri.uri,
      barcodeValue: genericObject.barcode.value
    });

    // En lugar de devolver JSON, redirigimos a la vista para que el usuario la vea
    res.redirect('/view');
  } catch (error) {
    console.error('Error creating generic credentials:', error);
    res.status(500).send(`<p>Error al crear la credencial: ${error.message}</p><a href="/create">Volver</a>`);
  }
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
