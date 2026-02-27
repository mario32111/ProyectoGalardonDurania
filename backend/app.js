var createError = require('http-errors');
var express = require('express');
var path = require('path');
var cookieParser = require('cookie-parser');
var logger = require('morgan');
var cors = require('cors');

var indexRouter = require('./routes/index');
var usersRouter = require('./routes/users');
var ganadoRouter = require('./routes/ganado');
var usuariosRouter = require('./routes/usuarios');
var inventarioRouter = require('./routes/inventario');
var chatbotRouter = require('./routes/chatbot');
var tramitesRouter = require('./routes/tramites');

var app = express();

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'jade');

app.use(cors());
app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

app.use('/', indexRouter);
app.use('/users', usersRouter);
app.use('/ganado', ganadoRouter);
app.use('/usuarios', usuariosRouter);
app.use('/inventario', inventarioRouter);
app.use('/chatbot', chatbotRouter);
app.use('/tramites', tramitesRouter);

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
