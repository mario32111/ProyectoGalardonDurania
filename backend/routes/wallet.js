const express = require('express');
const router = express.Router();
const { GoogleWalletService } = require('../services/walletService');
const { db } = require('../config/firebaseConfig');

const walletService = new GoogleWalletService();
const collectionName = 'wallet_credentials';

// Middleware para habilitar urlencoded si no está global
router.use(express.urlencoded({ extended: true }));

/**
 * Vista principal de billetera (opcional, integrada en el backend)
 */
router.get('/', (req, res) => {
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
          <li><a href="/wallet/create">Crear ID Ganadero (Prueba)</a></li>
          <li><a href="/wallet/view">Ver mis credenciales</a></li>
        </ul>
      </div>
    </body>
    </html>
  `);
});

router.get('/create', (req, res) => {
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
        <form action="/wallet/api/wallet/class" method="POST">
          <button type="submit" class="btn">Generar Credencial de Prueba</button>
        </form>
        <a href="/wallet" class="btn-back">Cancelar y volver</a>
      </div>
    </body>
    </html>
  `);
});

router.get('/view', async (req, res) => {
  let credentialsHtml = '<p style="color: #666;">No se han creado credenciales aún.</p>';
  
  try {
    const snapshot = await db.collection(collectionName).get();
    if (!snapshot.empty) {
      credentialsHtml = '<div style="display: flex; flex-direction: column; gap: 24px; align-items: center;">';
      snapshot.forEach(doc => {
        const cred = doc.data();
        credentialsHtml += `
          <div style="background-color: #0f4a3e; color: white; border-radius: 24px; padding: 24px; box-shadow: 0 10px 24px rgba(0,0,0,0.2); font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; position: relative; overflow: hidden; width: 100%; max-width: 380px; box-sizing: border-box;">
            
            <div style="display: flex; align-items: center; gap: 16px; margin-bottom: 16px;">
              <img src="${cred.logoUrl}" alt="Logo" style="width: 64px; height: 64px; border-radius: 50%; border: 3px solid #e0dfd5; object-fit: cover;">
              <span style="font-size: 1.5rem; font-weight: 500;">${cred.cardTitle}</span>
            </div>
            
            <div style="height: 1px; background-color: rgba(255,255,255,0.2); margin: 16px 0;"></div>
            <div style="font-size: 1.7rem; font-weight: 500; margin-bottom: 24px;">Asociación ganadera</div>
            <div style="height: 1px; background-color: rgba(255,255,255,0.2); margin: 16px 0;"></div>
            
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
            <div style="background-color: white; padding: 16px; border-radius: 8px; width: fit-content; margin: 0 auto 24px auto;">
              <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${cred.barcodeValue}" alt="QR Code" style="display: block; width: 150px; height: 150px;">
            </div>
            
            <div style="display: flex; gap: 12px; justify-content: center;">
              <a href="/wallet/edit/${doc.id}" style="flex: 1; text-align: center; padding: 10px; background: rgba(255,255,255,0.15); border: 1px solid rgba(255,255,255,0.3); border-radius: 8px; color: white; text-decoration: none; font-size: 0.9rem; font-weight: 500; transition: all 0.2s;">Editar</a>
              <form action="/wallet/api/wallet/delete/${doc.id}" method="POST" style="flex: 1; display: contents;">
                <button type="submit" style="flex: 1; padding: 10px; background: rgba(255,59,48,0.2); border: 1px solid rgba(255,59,48,0.4); border-radius: 8px; color: #ff3b30; cursor: pointer; font-size: 0.9rem; font-weight: 500; transition: all 0.2s;" onclick="return confirm('¿Estás seguro de eliminar esta credencial?')">Eliminar</button>
              </form>
            </div>
            
          </div>`;
      });
      credentialsHtml += '</div>';
    }
  } catch (err) {
    console.error('Error fetching credentials from Firestore:', err);
    credentialsHtml = '<p style="color: #d93025;">Error cargando las credenciales: ' + err.message + '</p>';
  }

  res.send(`
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Ver Credenciales</title>
      <style>
        body { font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f8f9fa; margin: 0; padding: 40px 20px; min-height: 100vh; display: flex; justify-content: center; }
        .container { width: 100%; max-width: 600px; background: white; border-radius: 20px; padding: 40px; box-shadow: 0 8px 24px rgba(0,0,0,0.04); }
        h1 { color: #202124; margin-top: 0; margin-bottom: 30px; font-size: 1.8rem; text-align: center; }
        .btn-back { display: block; width: max-content; margin: 40px auto 0; padding: 12px 24px; background-color: #f1f3f4; color: #3c4043; text-decoration: none; border-radius: 8px; font-weight: 600; transition: all 0.2s ease; }
        .btn-back:hover { background-color: #e8eaed; transform: translateY(-1px); }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Mis Credenciales</h1>
        ${credentialsHtml}
        <a href="/wallet" class="btn-back">← Volver al inicio</a>
      </div>
    </body>
    </html>
  `);
});

router.get('/edit/:id', async (req, res) => {
  try {
    const doc = await db.collection(collectionName).doc(req.params.id).get();
    if (!doc.exists) return res.redirect('/wallet/view');
    const cred = doc.data();

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
          <form action="/wallet/api/wallet/update/${doc.id}" method="POST">
            <div class="form-group">
              <label for="headerName">Nombre del Ganadero</label>
              <input type="text" id="headerName" name="headerName" value="${cred.headerName}" required>
            </div>
            <button type="submit" class="btn">Guardar Cambios</button>
          </form>
          <a href="/wallet/view" class="btn-back">Cancelar</a>
        </div>
      </body>
      </html>
    `);
  } catch (error) {
    res.status(500).send(`<p>Error al cargar la credencial: ${error.message}</p><a href="/wallet/view">Volver</a>`);
  }
});

router.post('/api/wallet/update/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { headerName } = req.body;
    
    // 1. Fetch from Firestore to ensure it exists
    const docRef = db.collection(collectionName).doc(id);
    const doc = await docRef.get();
    if (!doc.exists) throw new Error('Credencial no encontrada en la base de datos');

    // 2. Update Google Wallet Object
    const updateData = {
      "header": { "defaultValue": { "language": "es", "value": headerName } }
    };

    await walletService.updateGenericObject(id, updateData);

    // 3. Update Firestore
    await docRef.update({ headerName });

    res.redirect('/wallet/view');
  } catch (error) {
    console.error('Error updating generic credential:', error);
    res.status(500).send(`<p>Error al actualizar la credencial: ${error.message}</p><a href="/wallet/view">Volver</a>`);
  }
});

router.post('/api/wallet/delete/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // 1. Delete from Google Wallet
    try {
      await walletService.deleteGenericObject(id);
    } catch (e) {
      console.warn('Error deleting from Google Wallet (might not exist):', e.message);
    }

    // 2. Remove from Firestore
    await db.collection(collectionName).doc(id).delete();

    res.redirect('/wallet/view');
  } catch (error) {
    console.error('Error deleting generic credential:', error);
    res.status(500).send(`<p>Error al eliminar la credencial: ${error.message}</p><a href="/wallet/view">Volver</a>`);
  }
});

router.post('/api/wallet/class', async (req, res) => {
  try {
    const defaultIssuerId = process.env.GOOGLE_ISSUER_ID;
    const uniqueId = Date.now();
    const defaultClassName = `${defaultIssuerId}.test_generic_class_${uniqueId}`;
    const defaultObjectId = `${defaultIssuerId}.test_generic_object_${uniqueId}`;

    const classData = {
      id: defaultClassName,
      issuerName: 'ID Digital Universitaria',
    };
    
    await walletService.createGenericClass(defaultClassName, classData);

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

    await walletService.createGenericObject(defaultObjectId, genericObject);
    
    await db.collection(collectionName).doc(defaultObjectId).set({
      id: genericObject.id,
      cardTitle: genericObject.cardTitle.defaultValue.value,
      headerName: genericObject.header.defaultValue.value,
      logoUrl: genericObject.heroImage.sourceUri.uri,
      barcodeValue: genericObject.barcode.value,
      createdAt: new Date().toISOString()
    });

    res.redirect('/wallet/view');
  } catch (error) {
    console.error('Error creating generic credentials:', error);
    res.status(500).send(`<p>Error al crear la credencial: ${error.message}</p><a href="/wallet/create">Volver</a>`);
  }
});

// API para que el App Móvil obtenga el link directo de guardado
router.get('/api/save-link/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // 1. Buscamos la data del objeto en Firestore
    const doc = await db.collection(collectionName).doc(id).get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Credencial no encontrada' });
    
    const credData = doc.data();

    // 2. Re-construimos el objeto para el JWT (Google requiere la estructura completa del objeto)
    // Para simplificar, obtenemos el objeto actual desde el API de Google Wallet
    const client = await walletService.getClient();
    const googleResponse = await client.request({
      url: `https://walletobjects.googleapis.com/walletobjects/v1/genericObject/${id}`,
      method: 'GET'
    });
    
    const googleObject = googleResponse.data;

    // 3. Generamos el link firmado
    const saveUrl = await walletService.createSaveToWalletUrl(googleObject);

    res.json({ success: true, url: saveUrl });
  } catch (error) {
    console.error('Error generating Google Wallet link:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Listar todas las credenciales en formato JSON
router.get('/api/list', async (req, res) => {
  try {
    const snapshot = await db.collection(collectionName).get();
    const credentials = [];
    snapshot.forEach(doc => {
      credentials.push({ id: doc.id, ...doc.data() });
    });
    res.json({ success: true, data: credentials });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
