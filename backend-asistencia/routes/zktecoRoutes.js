const express = require('express');
const router = express.Router();
const zktecoController = require('../controllers/zktecoController');

// Protocolo ADMS de ZKTeco en /iclock/cdata
router.get('/cdata', zktecoController.handshake);
router.post('/cdata', zktecoController.recibirMarcaciones);

module.exports = router;
