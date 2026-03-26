require('dotenv').config();
var createError = require('http-errors');
var express = require('express');
var path = require('path');
var cookieParser = require('cookie-parser');
var logger = require('morgan');
var cors = require('cors');
const { verifyToken } = require('./middlewares/authMiddleware'); // <--- NUEVO: AUTH MIDDLEWARE

var indexRouter = require('./routes/index');
var usersRouter = require('./routes/users');
var ganadoRouter = require('./routes/ganado');
var usuariosRouter = require('./routes/usuarios');
var inventarioRouter = require('./routes/inventario');
var chatbotRouter = require('./routes/chatbot');
var tramitesRouter = require('./routes/tramites');
var uploadRouter = require('./routes/upload');
const walletRouter = require('./routes/wallet');

var app = express();

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'jade');

app.use(cors());
app.use(logger('dev'));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

// --- MIDDLEWARE DE AUTENTICACION GLOBAL PARA RUTAS DE DATOS ---
// Todas las rutas debajo de esta linea requieren el Header: Authorization Bearer <token>
app.use('/users', (req, res, next) => {
  if (req.path === '/login') return next();
  return verifyToken(req, res, next);
});
app.use('/ganado', verifyToken);
app.use('/usuarios', (req, res, next) => {
  if (req.path === '/login') return next();
  return verifyToken(req, res, next);
});
app.use('/inventario', verifyToken);
app.use('/chatbot', verifyToken);
app.use('/tramites', verifyToken);
app.use('/upload', verifyToken);
// app.use('/wallet', verifyToken); // Removido para acceso directo via navegador similar al microservicio original

app.use('/', indexRouter);
app.use('/users', usersRouter);
app.use('/ganado', ganadoRouter);
app.use('/usuarios', usuariosRouter);
app.use('/inventario', inventarioRouter);
app.use('/chatbot', chatbotRouter);
app.use('/tramites', tramitesRouter);
app.use('/upload', uploadRouter);
app.use('/wallet', walletRouter);

// catch 404 and forward to error handler
app.use(function (req, res, next) {
  next(createError(404));
});

// error handler
app.use(function (err, req, res, next) {
  const status = err.status || 500;

  // Para rutas de API, devolver JSON en lugar de HTML
  if (req.originalUrl.startsWith('/chatbot') ||
    req.originalUrl.startsWith('/ganado') ||
    req.originalUrl.startsWith('/usuarios') ||
    req.originalUrl.startsWith('/inventario') ||
    req.originalUrl.startsWith('/tramites') ||
    req.originalUrl.startsWith('/upload') ||
    req.originalUrl.startsWith('/users') ||
    req.headers.accept?.includes('application/json')) {
    return res.status(status).json({
      success: false,
      message: err.message || 'Error interno del servidor',
      error: req.app.get('env') === 'development' ? err.stack : undefined
    });
  }

  // Para vistas HTML normales
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};
  res.status(status);
  res.render('error');
});

module.exports = app;
