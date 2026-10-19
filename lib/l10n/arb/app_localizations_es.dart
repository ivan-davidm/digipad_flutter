// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'DigiTower 3D';

  @override
  String get menuVirtualMirror => 'Espejo Virtual';

  @override
  String get menuSimulations => 'Simulaciones';

  @override
  String get menuLenses3D => 'Lentes 3D';

  @override
  String get menuCosmeticLenses => 'Lentes Cosméticos';

  @override
  String get menuMeasurements => 'Mediciones';

  @override
  String get menuVisualHealth => 'Salud Visual';

  @override
  String get ok => 'Aceptar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String dialogNavigatingContent(String module) {
    return 'Navegando al módulo de $module.';
  }

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get vmNoImages =>
      'Aún no hay imágenes.\nCaptura una o selecciona desde tu galería para comenzar';

  @override
  String get vmDragAndDrop => 'Arrastra y suelta fotos';

  @override
  String get vmPickOrTake =>
      'Selecciona una foto de tu galería o toma una nueva';

  @override
  String get vmDropHere => 'Suelta la imagen aquí';

  @override
  String get galleryDeleteTitle => '¿Eliminar imagen?';

  @override
  String get galleryDeleteContent =>
      'Esto eliminará permanentemente la imagen del almacenamiento.';

  @override
  String get vhNoTests => 'Aún no hay pruebas.';

  @override
  String get vhSelectTest => 'Selecciona una prueba de salud visual';

  @override
  String vhTestSummary(int index, int total) {
    return 'Prueba $index de $total';
  }

  @override
  String get vhSelectAbove => 'Selecciona una prueba de la galería de arriba';

  @override
  String get vhCatVisionTests => 'Test de Visión';

  @override
  String get vhCatIshihara => 'Bicromatico Ishihara';

  @override
  String get vhCatChildrenTest => 'Bicromático Niños';

  @override
  String get vhCatAmetropia => 'Ametropías';

  @override
  String get vhCatPathologies => 'Patologías';

  @override
  String get vhCatAmsler => 'Rejilla de Amsler';

  @override
  String get lensThicknessSimulator => 'Simulador de Espesor de Lentes';

  @override
  String get lensConfiguration => 'Configuración de Lente';

  @override
  String get materialIndex => 'Índice del Material';

  @override
  String get higherIndexHint => 'Índice mayor = lente más delgada';

  @override
  String get prescription => 'Graduación';

  @override
  String rangeDiopters(int min, int max) {
    return 'Rango: $min-$max dioptrías';
  }

  @override
  String get frameType => 'Tipo de Armazón';

  @override
  String get imageNotAvailable => 'Imagen no disponible';

  @override
  String get tryDifferentSettings => 'Prueba diferentes ajustes';

  @override
  String get fullView => 'Vista completa';

  @override
  String get detailView => 'Vista de detalle';

  @override
  String get lensSimulatorTitle => 'Simulador de Lentes';

  @override
  String get refractiveConditions => 'Condiciones refractivas';

  @override
  String get lensTreatments => 'Tratamientos de lentes';

  @override
  String get withoutLens => 'Sin lente';

  @override
  String scenesCount(int count) {
    return '$count escenas';
  }

  @override
  String lensesAvailable(int count) {
    return '$count lentes disponibles';
  }

  @override
  String get selectLensLabel => 'Selecciona una lente:';

  @override
  String get dividerLabel => 'Divisor';

  @override
  String get lensLabel => 'Lente';

  @override
  String get verticalLabel => 'Vertical';

  @override
  String get horizontalLabel => 'Horizontal';

  @override
  String get dragDivider => 'Arrastra el divisor';

  @override
  String get loadingSimulation => 'Cargando simulación...';

  @override
  String get goBack => 'Volver';

  @override
  String get info => 'Información';

  @override
  String get measurementsModuleTitle => 'Módulo de Mediciones';

  @override
  String get measurementsModuleSubtitle =>
      'La funcionalidad de medición se implementará aquí';

  @override
  String get cameraRequiredTitle => 'Cámara requerida';

  @override
  String get cameraRequiredContent =>
      'El acceso a la cámara ha sido denegado permanentemente. Habilítalo en la configuración del sistema para usar esta función.';

  @override
  String get openSettings => 'Abrir configuración';

  @override
  String get platformNotSupported => 'Plataforma no soportada';

  @override
  String get placeReferenceHere => 'Coloque la referencia aquí';

  @override
  String get cameraPermissionRequired => 'Permiso de cámara requerido';

  @override
  String get cameraPermissionExplain =>
      'Necesitamos acceso a la cámara para detectar rostros y referencias.';

  @override
  String get grantPermission => 'Conceder permiso';

  @override
  String detectionIncomplete(int found) {
    return 'Detección incompleta. Se encontraron $found/4 círculos. Intenta con una imagen más clara.';
  }

  @override
  String captureFailed(int found) {
    return 'Captura fallida: Se encontraron $found círculos (se requieren 4). Ajusta la iluminación o distancia.';
  }

  @override
  String get measureAdjustments => 'Ajuste de Medidas';

  @override
  String get guides => 'Guías';

  @override
  String referenceShort(int ref) {
    return 'Ref: $ref';
  }

  @override
  String get unitMm => 'mm';

  @override
  String get ipdDi => 'DIP (DI)';

  @override
  String get bridge => 'Puente';

  @override
  String get frameW => 'Ancho Aro';

  @override
  String get frameH => 'Alto Aro';

  @override
  String get rightEyeP1 => 'Ojo Der (P1)';

  @override
  String get leftEyeP2 => 'Ojo Izq (P2)';

  @override
  String dnpShort(String value) {
    return 'DNP: $value';
  }

  @override
  String heightShort(String value) {
    return 'Alt: $value';
  }

  @override
  String diamShort(String value) {
    return 'Diam: $value';
  }

  @override
  String get shareResults => 'Compartir Resultados';

  @override
  String get calibration => 'Calibración';

  @override
  String get editMode => 'Modo Edición';

  @override
  String get zoomMode => 'Modo Zoom';

  @override
  String get resetZoom => 'Resetear Zoom';

  @override
  String get horizontalAdjustment => 'Ajuste Horizontal';

  @override
  String get verticalAdjustment => 'Ajuste Vertical';

  @override
  String get measurementsResultsTitle => 'Resultados';

  @override
  String get copyLabel => 'Copiar';

  @override
  String get shareLabel => 'Compartir';

  @override
  String get measurementsShareSubject => 'Mediciones';

  @override
  String get exitEditionTitle => 'Salir de la edición';

  @override
  String get exitEditionContent => '¿Querés salir sin guardar las mediciones?';

  @override
  String get exitLabel => 'Salir';

  @override
  String get pantoscopicAngle => 'Ángulo Pantoscópico';

  @override
  String get pantoscopicAngleShort => 'Ángulo Pant.';

  @override
  String get leftEye => 'Ojo Izquierdo';

  @override
  String get bothEyes => 'Ambos Ojos';

  @override
  String get rightEye => 'Ojo Derecho';

  @override
  String get size => 'Tamaño';

  @override
  String get opacity => 'Opacidad';

  @override
  String get eyelid => 'Párpado';

  @override
  String get takeOrSelectStart =>
      'Toma una foto o selecciona desde la galería para comenzar';

  @override
  String get selectBrand => 'Selecciona Marca';

  @override
  String get selectColor => 'Selecciona Color';

  @override
  String get onLabel => 'Encendido';

  @override
  String get offLabel => 'Apagado';

  @override
  String get detectionLabel => 'Detección';

  @override
  String get overlayLabel => 'Superposición';

  @override
  String get simCatMyopia => 'Miopía';

  @override
  String get simCatMyopiaDesc =>
      'Dificultad para ver claramente objetos lejanos (miopía)';

  @override
  String get simCatPresbyopia => 'Presbicia';

  @override
  String get simCatPresbyopiaDesc =>
      'Dificultad para ver claramente objetos lejanos (presbicia)';

  @override
  String get simSceneKitchen => 'Cocina';

  @override
  String get simSceneMarket => 'Mercado';

  @override
  String get simSceneGrocery => 'Supermercado';

  @override
  String get simSceneClothingStore => 'Tienda de Ropa';

  @override
  String get simLensMonofocalNear => 'Monofocal Cerca';

  @override
  String get simLensMonofocalFar => 'Monofocal Lejos';

  @override
  String get simCatMultifocal => 'Progresivos';

  @override
  String get simCatMultifocalDesc =>
      'Comparación de calidad de lentes progresivos';

  @override
  String get simSceneClothing => 'Ropa';

  @override
  String get simQualityEconomy => 'Económico';

  @override
  String get simQualityStandard => 'Estándar';

  @override
  String get simQualityGood => 'Bueno';

  @override
  String get simQualityPremium => 'Premium';

  @override
  String get simCatBifocal => 'Bifocal';

  @override
  String get simCatBifocalDesc =>
      'Comparación entre lentes bifocales y multifocales';

  @override
  String get simSceneOffice => 'Oficina';

  @override
  String get simSceneDriving => 'Conducción';

  @override
  String get simLensInvisibleBifocal => 'Bifocal Invisible';

  @override
  String get simLensMultifocal => 'Multifocal';

  @override
  String get simCatPolarized => 'Polarizado';

  @override
  String get simCatPolarizedDesc => 'Reducción de reflejos y deslumbramiento';

  @override
  String get simSceneGolf => 'Golf';

  @override
  String get simSceneBeach => 'Playa';

  @override
  String get simSceneTennis => 'Tenis';

  @override
  String get simSceneYacht => 'Yate';

  @override
  String get simSceneMotorcycle => 'Motocicleta';

  @override
  String get simCatAntiReflective => 'Antirreflejo';

  @override
  String get simCatAntiReflectiveDesc =>
      'Reducción de reflejos en la lente y mejor claridad';

  @override
  String get simSceneBaseball => 'Béisbol';

  @override
  String get simSceneBasketball => 'Baloncesto';

  @override
  String get simSceneSoccer => 'Fútbol';

  @override
  String get simSceneConcert => 'Concierto';

  @override
  String get simSceneBridge => 'Puente';

  @override
  String get simCatDriveWear => 'DriveWear';

  @override
  String get simCatDriveWearDesc =>
      'Lentes optimizados para conducir en diferentes condiciones';

  @override
  String get simSceneDrivingSunny => 'Conducción (Soleado)';

  @override
  String get simSceneDrivingCloudy => 'Conducción (Nublado)';

  @override
  String get simSceneGolfSunny => 'Golf (Soleado)';

  @override
  String get simSceneGolfCloudy => 'Golf (Nublado)';

  @override
  String get simSceneBeachSunny => 'Playa (Soleado)';

  @override
  String get simSceneBeachCloudy => 'Playa (Nublado)';

  @override
  String get simSceneMotorcycleSunny => 'Motocicleta (Soleado)';

  @override
  String get simSceneMotorcycleCloudy => 'Motocicleta (Nublado)';

  @override
  String get simSceneTennisSunny => 'Tenis (Soleado)';

  @override
  String get simSceneTennisCloudy => 'Tenis (Nublado)';

  @override
  String get simSceneYachtSunny => 'Yate (Soleado)';

  @override
  String get simSceneYachtCloudy => 'Yate (Nublado)';

  @override
  String get simCatPhotochromic => 'Fotocromático';

  @override
  String get simCatPhotochromicDesc =>
      'Lentes que se adaptan a las condiciones de luz';

  @override
  String get simSceneOpticStore => 'Óptica';

  @override
  String get simColorGray => 'Gris';

  @override
  String get simColorBrown => 'Marrón';

  @override
  String get simColorGreen => 'Verde';

  @override
  String get simColorSunBalance => 'SunBalance';

  @override
  String get simCatSolar => 'Solar';

  @override
  String get simCatSolarDesc =>
      'Protección solar con recubrimiento antirreflejo';

  @override
  String get simSceneBeach2 => 'Playa 2';

  @override
  String get simSceneCar => 'Auto';

  @override
  String get simLensWithAR => 'Con AR';

  @override
  String get simCatTint => 'Tinte';

  @override
  String get simCatTintDesc =>
      'Tintes de lentes personalizables para diferentes entornos';

  @override
  String get simColorYellow => 'Amarillo';

  @override
  String get simColorAqua => 'Aguamarina';

  @override
  String get simColorBlue => 'Azul';

  @override
  String get simColorOrange => 'Naranja';

  @override
  String get simColorRed => 'Rojo';

  @override
  String get activationTitle => 'Activación del Dispositivo';

  @override
  String get activationEnterEmail =>
      'Por favor ingrese su correo electrónico para solicitar acceso.';

  @override
  String get activationEmailLabel => 'Correo Electrónico';

  @override
  String get activationRequestAccess => 'Solicitar Acceso';

  @override
  String get activationAwaitingApproval => 'Esperando Aprobación';

  @override
  String activationPendingMessage(String email) {
    return 'Su solicitud de activación del dispositivo está pendiente de aprobación.\nCorreo: $email';
  }

  @override
  String get activationRefreshStatus => 'Actualizar';

  @override
  String get activationConnectionRequired => 'Conexión Requerida';

  @override
  String get activationOfflineLimitReached =>
      'Se ha alcanzado el límite de uso sin conexión.';

  @override
  String get activationRetryConnection => 'Reintentar Conexión';

  @override
  String get activationErrorTitle => 'Error';

  @override
  String get activationEmailInvalid => 'Por favor ingrese un correo válido';

  @override
  String get activationRequestExists =>
      'Ya existe una solicitud para este correo.';

  @override
  String get activationNoInternet =>
      'Sin conexión a internet y no activado previamente.';

  @override
  String get activationConnectionTimeout =>
      'Tiempo de conexión agotado. Por favor verifique su internet.';

  @override
  String get nativeSplitGalleryOnlyHint =>
      'Toca el botón inferior para abrir la cámara\no selecciona una foto de tu galería';

  @override
  String get nativeSplitModeGallery => 'Galería';

  @override
  String get nativeSplitModeCamera => 'Cámara';

  @override
  String get lensType => 'Tipo de Lente';

  @override
  String get simCatAspheric => 'Asférico';

  @override
  String get simCatAsphericDesc => 'Diseño de lente más plano y estético';

  @override
  String get simCatBlueFilter => 'Filtro Luz Azul';

  @override
  String get simCatBlueFilterDesc =>
      'Protección contra luz azul de pantallas digitales';

  @override
  String get simCatMonofocal => 'Monofocal';

  @override
  String get simCatMonofocalDesc =>
      'Corrección visual con un único punto focal';

  @override
  String get menuPhotoSync => 'Photo Sync';

  @override
  String get photoSyncTitle => 'Photo Sync';

  @override
  String get photoSyncSubtitle => 'Transferencia de fotos sin internet';

  @override
  String get photoSyncHost => 'TOTEM';

  @override
  String get photoSyncHostDesc => 'Este dispositivo recibe fotos';

  @override
  String get photoSyncClient => 'CELULAR';

  @override
  String get photoSyncClientDesc => 'Este dispositivo envía fotos';

  @override
  String get photoSyncScanQr => 'Escanear código QR';

  @override
  String get photoSyncAutoReconnect => 'Reconectar automáticamente';

  @override
  String get photoSyncConnected => 'Conectado al totem';

  @override
  String get photoSyncTakePhoto => 'Sacar foto';

  @override
  String get photoSyncSending => 'Enviando foto...';

  @override
  String get photoSyncSent => '¡Foto enviada!';

  @override
  String get photoSyncSendError => 'Error al enviar. Intentá de nuevo.';

  @override
  String get photoSyncWaiting => 'Esperando conexiones...';

  @override
  String get photoSyncStarting => 'Iniciando punto de acceso...';

  @override
  String get photoSyncStartingDesc => 'Esto puede tomar unos segundos';

  @override
  String get photoSyncReceivedPhotos => 'Fotos recibidas';

  @override
  String photoSyncDevicesConnected(int count) {
    return '$count dispositivo(s) conectado(s)';
  }

  @override
  String get photoSyncNoConnections => 'Esperando conexiones...';

  @override
  String get photoSyncRetry => 'Reintentar';

  @override
  String get photoSyncRoleHostActiveSubtitle =>
      'Sesión activa – recibiendo fotos';

  @override
  String get photoSyncRoleHostInactiveSubtitle =>
      'Este dispositivo recibe fotos';

  @override
  String get photoSyncRoleHostActiveDesc =>
      'Podés usar el resto de la app normalmente.\nLas fotos seguirán llegando en segundo plano.';

  @override
  String get photoSyncRoleHostInactiveDesc =>
      'Mostrará un código QR para que otros\ndispositivos se conecten';

  @override
  String get photoSyncRoleClientTitle => 'CELULAR';

  @override
  String get photoSyncRoleClientSubtitle => 'Este dispositivo envía fotos';

  @override
  String get photoSyncRoleClientDesc =>
      'Escaneá el QR del totem para\nconectarte y sacar fotos';

  @override
  String get photoSyncDisconnect => 'DESCONECTAR TOTEM';

  @override
  String photoSyncPhotosCount(int count) {
    return '$count fotos';
  }

  @override
  String get photoSyncRoleSubtitle => 'Sincronización de fotos';

  @override
  String get simSceneBuildingPositive => 'Edificio Positivo';

  @override
  String get simSceneBuildingNegative => 'Edificio Negativo';

  @override
  String get simSceneTextPositive => 'Lectura Positivo';

  @override
  String get simSceneTextNegative => 'Lectura Negativo';

  @override
  String get galleryTitle => 'Galería';

  @override
  String get vmInternalGallery => 'Galería Interna';

  @override
  String get cosmeticLensSaved => '¡Imagen guardada con éxito!';

  @override
  String get cosmeticLensSaveError => 'Error al guardar la imagen';

  @override
  String get simSceneSmartphone => 'Celular';

  @override
  String get simSceneStore => 'Tienda';

  @override
  String get simLensProgressive => 'Lente Progresiva';

  @override
  String get simLensNoLens => 'Sin Lente';

  @override
  String get saveMeasurement => 'GUARDAR MEDICIÓN';

  @override
  String get saveMeasurementDialogTitle => 'Guardar medición';

  @override
  String get saveToGallery => 'Galería interna';

  @override
  String get saveToGalleryDesc => 'Guarda la foto y el ángulo pantoscópico';

  @override
  String get saveToMeasurements => 'Mediciones';

  @override
  String get saveToMeasurementsDesc =>
      'Guarda el estado completo para reeditar';

  @override
  String get patientData => 'Datos del paciente';

  @override
  String get patientFirstName => 'Nombre';

  @override
  String get patientLastName => 'Apellido';

  @override
  String get optionalHint => 'Opcional';

  @override
  String get measurementSaved => 'Medición guardada';

  @override
  String get photoSavedToGallery => 'Foto guardada en galería';

  @override
  String get myMeasurements => 'Mis mediciones';

  @override
  String get noSavedMeasurements => 'No hay mediciones guardadas';

  @override
  String get sortByDate => 'Por fecha';

  @override
  String get sortByName => 'Por nombre';

  @override
  String get deleteMeasurementTitle => '¿Eliminar medición?';

  @override
  String get deleteMeasurementContent =>
      'Esta medición se eliminará permanentemente.';

  @override
  String get unknownPatient => 'Paciente desconocido';

  @override
  String get updateMeasurement => 'Actualizar medición';

  @override
  String get save => 'Guardar';

  @override
  String get hubNewMeasurement => 'Nueva Medición';

  @override
  String get hubDetectorNotReady =>
      'El detector aún no está listo. Intenta de nuevo.';

  @override
  String get hubAnalyzing => 'Analizando...';

  @override
  String heightTopShort(String value) {
    return 'Alt.sup: $value';
  }

  @override
  String get frameOuterW => 'Ancho ext.';

  @override
  String get frameWidthField => 'Ancho del armazón';

  @override
  String get frameWidthHint => 'ej. 119';

  @override
  String get hubNoAccessory => 'Medición remota';

  @override
  String get frameWidthMissingWarning =>
      'Ingresá el ancho del armazón para calcular';

  @override
  String get cleanView => 'Vista limpia';

  @override
  String get simAdaptLabel => 'Adaptación';

  @override
  String get simAdaptStandard => 'Estándar';

  @override
  String get simAdaptGood => 'Buena';

  @override
  String get simAdaptPremium => 'Premium';

  @override
  String get simReplay => 'Reproducir';

  @override
  String get sinGlasses => 'Sin lentes';

  @override
  String get sharedView => 'Vista compartida';

  @override
  String get lensLabelA => 'Lente A';

  @override
  String get lensLabelB => 'Lente B';

  @override
  String get comparatorLabel => 'Comparador';

  @override
  String get settingsCopied => 'Configuración copiada a B';

  @override
  String get copyAtoB => 'Copiar A a B';
}
