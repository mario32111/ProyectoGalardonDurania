const openAIService = require('./services/openAIService');
require('dotenv').config();

async function testAnalysis() {
    console.log("🚀 Iniciando prueba de análisis de documento con IA...");
    
    // URL de una imagen de prueba (ejemplo de un certificado o documento)
    const testImageUrl = "https://raw.githubusercontent.com/mario32111/ProyectoGalardonDurania/main/doc_test.jpg"; // URL hipotética o real de prueba
    
    try {
        const result = await openAIService.analyzeDocument(
            "https://upload.wikimedia.org/wikipedia/commons/d/d5/Standard_Medical_Certificate.jpg", 
            "certificado_medico_test.jpg"
        );
        
        console.log("📊 Resultado del análisis:");
        console.log(JSON.stringify(result, null, 2));
        
        if (result.hasOwnProperty('legible') && result.hasOwnProperty('veraz')) {
            console.log("✅ La estructura del resultado es correcta.");
        } else {
            console.log("❌ La estructura del resultado es INCORRECTA.");
        }
    } catch (error) {
        console.error("❌ Error en la prueba:", error);
    }
}

testAnalysis();
