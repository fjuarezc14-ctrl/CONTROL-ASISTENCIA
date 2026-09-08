const express = require('express');
const router = express.Router();
const asistenciaController = require('../controllers/asistenciaController');

// Rutas de asistencia
router.get('/asistencias/auxiliar', asistenciaController.getResumenAuxiliar);
router.get('/asistencias/admin', asistenciaController.getResumenAuxiliar); // Alias para admin
router.get('/asistencias/padre', asistenciaController.getHijosPadre);
router.post('/asistencias/justificar', asistenciaController.justificarFalta);
router.post('/asistencias/manual', asistenciaController.marcarManual);

module.exports = router;
