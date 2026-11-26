// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'DigiTower 3D';

  @override
  String get menuVirtualMirror => 'Espelho Virtual';

  @override
  String get menuSimulations => 'Simulações';

  @override
  String get menuLenses3D => 'Lentes 3D';

  @override
  String get menuCosmeticLenses => 'Lentes Cosméticas';

  @override
  String get menuMeasurements => 'Medições';

  @override
  String get menuVisagismo => 'Visagismo';

  @override
  String get menuVisualHealth => 'Saúde Visual';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Excluir';

  @override
  String dialogNavigatingContent(String module) {
    return 'Navegando para o módulo $module.';
  }

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get vmNoImages =>
      'Nenhuma imagem carregada ainda.\nCapture uma ou selecione da galeria para começar';

  @override
  String get vmDragAndDrop => 'Arraste e solte fotos';

  @override
  String get vmPickOrTake => 'Escolha uma foto da galeria ou tire uma nova';

  @override
  String get vmDropHere => 'Solte a imagem aqui';

  @override
  String get vmCameraPermissionTitle => 'Permissão de câmera necessária';

  @override
  String get vmCameraPermissionBody =>
      'O DigiPad precisa de acesso à câmera para tirar fotos.\nAtive em Configurações › Aplicativos › DigiPad › Permissões.';

  @override
  String get vmOpenSettings => 'Abrir Configurações';

  @override
  String get vmNoCameraFound => 'Nenhuma câmera foi encontrada.';

  @override
  String get vmCameraInitError => 'Não foi possível iniciar a câmera.';

  @override
  String get vmAngleCalibrated => 'Ângulo calibrado para 0°';

  @override
  String get vmCaptureError => 'Erro ao tirar a foto. Tente novamente.';

  @override
  String get vmCameraAccessNeededTitle => 'Acesso à câmera necessário';

  @override
  String get vmCameraAccessNeededBody =>
      'O DigiPad precisa usar a câmera para tirar a foto.';

  @override
  String get vmGivePermission => 'Conceder permissão';

  @override
  String get vmCalibratedAbbr => 'cal';

  @override
  String vmSelectedCountOne(int count) {
    return '$count selecionada';
  }

  @override
  String vmSelectedCountOther(int count) {
    return '$count selecionadas';
  }

  @override
  String get galleryDeleteTitle => 'Excluir imagem?';

  @override
  String get galleryDeleteContent =>
      'Isso removerá permanentemente a imagem do armazenamento.';

  @override
  String get vhNoTests => 'Nenhum teste carregado.';

  @override
  String get vhSelectTest => 'Selecione um teste de saúde visual';

  @override
  String vhTestSummary(int index, int total) {
    return 'Teste $index de $total';
  }

  @override
  String get vhSelectAbove => 'Selecione um teste na galeria acima';

  @override
  String get vhCatVisionTests => 'Testes de Visão';

  @override
  String get vhCatIshihara => 'Bicromatico Ishihara';

  @override
  String get vhCatChildrenTest => 'Bicromático Crianças';

  @override
  String get vhCatAmetropia => 'Ametropias';

  @override
  String get vhCatPathologies => 'Patologias';

  @override
  String get vhCatAmsler => 'Grade de Amsler';

  @override
  String get lensThicknessSimulator => 'Simulador de Espessura de Lentes';

  @override
  String get lensConfiguration => 'Configuração da Lente';

  @override
  String get materialIndex => 'Índice do Material';

  @override
  String get higherIndexHint => 'Índice maior = lente mais fina';

  @override
  String get prescription => 'Prescrição';

  @override
  String rangeDiopters(int min, int max) {
    return 'Faixa: $min-$max dioptrias';
  }

  @override
  String get frameType => 'Tipo de Armação';

  @override
  String get imageNotAvailable => 'Imagem indisponível';

  @override
  String get tryDifferentSettings => 'Tente configurações diferentes';

  @override
  String get fullView => 'Visão completa';

  @override
  String get detailView => 'Visão detalhada';

  @override
  String get lensSimulatorTitle => 'Simulador de Lentes';

  @override
  String get refractiveConditions => 'Condições refrativas';

  @override
  String get lensTreatments => 'Tratamentos de lentes';

  @override
  String get withoutLens => 'Sem lente';

  @override
  String scenesCount(int count) {
    return '$count cenas';
  }

  @override
  String lensesAvailable(int count) {
    return '$count lentes disponíveis';
  }

  @override
  String get selectLensLabel => 'Selecione uma lente:';

  @override
  String get dividerLabel => 'Divisor';

  @override
  String get lensLabel => 'Lente';

  @override
  String get verticalLabel => 'Vertical';

  @override
  String get horizontalLabel => 'Horizontal';

  @override
  String get dragDivider => 'Arraste o divisor';

  @override
  String get loadingSimulation => 'Carregando simulação...';

  @override
  String get goBack => 'Voltar';

  @override
  String get info => 'Informação';

  @override
  String get measurementsModuleTitle => 'Módulo de Medidas';

  @override
  String get measurementsModuleSubtitle =>
      'A funcionalidade de medição será implementada aqui';

  @override
  String get cameraRequiredTitle => 'Câmera necessária';

  @override
  String get cameraRequiredContent =>
      'O acesso à câmera foi negado permanentemente. Habilite-o nas configurações do sistema para usar este recurso.';

  @override
  String get openSettings => 'Abrir configurações';

  @override
  String get platformNotSupported => 'Plataforma não suportada';

  @override
  String get placeReferenceHere => 'Coloque a referência aqui';

  @override
  String get cameraPermissionRequired => 'Permissão de câmera necessária';

  @override
  String get cameraPermissionExplain =>
      'Precisamos de acesso à câmera para detectar rostos e marcadores de referência.';

  @override
  String get grantPermission => 'Conceder permissão';

  @override
  String detectionIncomplete(int found) {
    return 'Detecção incompleta. Encontrados $found/4 círculos. Tente uma imagem mais clara.';
  }

  @override
  String captureFailed(int found) {
    return 'Falha na captura: Encontrados $found círculos (4 necessários). Ajuste a iluminação ou distância.';
  }

  @override
  String get measureAdjustments => 'Ajuste de Medidas';

  @override
  String get guides => 'Guias';

  @override
  String referenceShort(int ref) {
    return 'Ref: $ref';
  }

  @override
  String get unitMm => 'mm';

  @override
  String get ipdDi => 'DIP (DI)';

  @override
  String get bridge => 'Ponte';

  @override
  String get frameW => 'Largura da armação';

  @override
  String get frameH => 'Altura da armação';

  @override
  String get rightEyeP1 => 'Olho Dir (P1)';

  @override
  String get leftEyeP2 => 'Olho Esq (P2)';

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
  String get shareResults => 'Compartilhar Resultados';

  @override
  String get calibration => 'Calibração';

  @override
  String get editMode => 'Modo Edição';

  @override
  String get zoomMode => 'Modo Zoom';

  @override
  String get resetZoom => 'Redefinir Zoom';

  @override
  String get horizontalAdjustment => 'Ajuste Horizontal';

  @override
  String get verticalAdjustment => 'Ajuste Vertical';

  @override
  String get measurementsResultsTitle => 'Resultados';

  @override
  String get copyLabel => 'Copiar';

  @override
  String get shareLabel => 'Compartilhar';

  @override
  String get measurementsShareSubject => 'Medições';

  @override
  String get exitEditionTitle => 'Sair da edição';

  @override
  String get exitEditionContent => 'Sair sem salvar as medições?';

  @override
  String get exitLabel => 'Sair';

  @override
  String get pantoscopicAngle => 'Ângulo Pantoscópico';

  @override
  String get pantoscopicAngleShort => 'Ângulo Pant.';

  @override
  String get leftEye => 'Olho Esquerdo';

  @override
  String get bothEyes => 'Ambos os Olhos';

  @override
  String get rightEye => 'Olho Direito';

  @override
  String get size => 'Tamanho';

  @override
  String get opacity => 'Opacidade';

  @override
  String get eyelid => 'Pálpebra';

  @override
  String get takeOrSelectStart =>
      'Tire uma foto ou selecione da Galeria para começar';

  @override
  String get selectBrand => 'Selecione a Marca';

  @override
  String get selectColor => 'Selecione a Cor';

  @override
  String get onLabel => 'Ligado';

  @override
  String get offLabel => 'Desligado';

  @override
  String get detectionLabel => 'Detecção';

  @override
  String get overlayLabel => 'Sobreposição';

  @override
  String get simCatMyopia => 'Miopia';

  @override
  String get simCatMyopiaDesc =>
      'Dificuldade para ver objetos distantes com clareza (miopia)';

  @override
  String get simCatPresbyopia => 'Presbiopia';

  @override
  String get simCatPresbyopiaDesc =>
      'Dificuldade para ver claramente objetos próximos (presbiopia)';

  @override
  String get simSceneKitchen => 'Cozinha';

  @override
  String get simSceneMarket => 'Mercado';

  @override
  String get simSceneGrocery => 'Supermercado';

  @override
  String get simSceneClothingStore => 'Loja de Roupas';

  @override
  String get simLensMonofocalNear => 'Monofocal Perto';

  @override
  String get simLensMonofocalFar => 'Monofocal Longe';

  @override
  String get simCatMultifocal => 'Progressivos';

  @override
  String get simCatMultifocalDesc =>
      'Comparação de qualidade de lentes progressivas';

  @override
  String get simSceneClothing => 'Roupas';

  @override
  String get simQualityEconomy => 'Econômico';

  @override
  String get simQualityStandard => 'Padrão';

  @override
  String get simQualityGood => 'Bom';

  @override
  String get simQualityPremium => 'Premium';

  @override
  String get simCatBifocal => 'Bifocal';

  @override
  String get simCatBifocalDesc =>
      'Comparação entre lentes bifocais e multifocais';

  @override
  String get simSceneOffice => 'Escritório';

  @override
  String get simSceneDriving => 'Direção';

  @override
  String get simLensInvisibleBifocal => 'Bifocal Invisível';

  @override
  String get simLensMultifocal => 'Multifocal';

  @override
  String get simCatPolarized => 'Polarizado';

  @override
  String get simCatPolarizedDesc => 'Redução de reflexos e ofuscamento';

  @override
  String get simSceneGolf => 'Golfe';

  @override
  String get simSceneBeach => 'Praia';

  @override
  String get simSceneTennis => 'Tênis';

  @override
  String get simSceneYacht => 'Iate';

  @override
  String get simSceneMotorcycle => 'Motocicleta';

  @override
  String get simCatAntiReflective => 'Antirreflexo';

  @override
  String get simCatAntiReflectiveDesc =>
      'Redução de reflexos na lente e melhor clareza';

  @override
  String get simSceneBaseball => 'Beisebol';

  @override
  String get simSceneBasketball => 'Basquete';

  @override
  String get simSceneSoccer => 'Futebol';

  @override
  String get simSceneConcert => 'Show';

  @override
  String get simSceneBridge => 'Ponte';

  @override
  String get simCatDriveWear => 'DriveWear';

  @override
  String get simCatDriveWearDesc =>
      'Lentes otimizadas para dirigir em diferentes condições';

  @override
  String get simSceneDrivingSunny => 'Direção (Ensolarado)';

  @override
  String get simSceneDrivingCloudy => 'Direção (Nublado)';

  @override
  String get simSceneGolfSunny => 'Golfe (Ensolarado)';

  @override
  String get simSceneGolfCloudy => 'Golfe (Nublado)';

  @override
  String get simSceneBeachSunny => 'Praia (Ensolarado)';

  @override
  String get simSceneBeachCloudy => 'Praia (Nublado)';

  @override
  String get simSceneMotorcycleSunny => 'Motocicleta (Ensolarado)';

  @override
  String get simSceneMotorcycleCloudy => 'Motocicleta (Nublado)';

  @override
  String get simSceneTennisSunny => 'Tênis (Ensolarado)';

  @override
  String get simSceneTennisCloudy => 'Tênis (Nublado)';

  @override
  String get simSceneYachtSunny => 'Iate (Ensolarado)';

  @override
  String get simSceneYachtCloudy => 'Iate (Nublado)';

  @override
  String get simCatPhotochromic => 'Fotocromático';

  @override
  String get simCatPhotochromicDesc =>
      'Lentes que se adaptam às condições de luz';

  @override
  String get simSceneOpticStore => 'Ótica';

  @override
  String get simColorGray => 'Cinza';

  @override
  String get simColorBrown => 'Marrom';

  @override
  String get simColorGreen => 'Verde';

  @override
  String get simColorSunBalance => 'SunBalance';

  @override
  String get simCatSolar => 'Solar';

  @override
  String get simCatSolarDesc => 'Proteção solar com revestimento antirreflexo';

  @override
  String get simSceneBeach2 => 'Praia 2';

  @override
  String get simSceneCar => 'Carro';

  @override
  String get simLensWithAR => 'Com AR';

  @override
  String get simCatTint => 'Tonalidade';

  @override
  String get simCatTintDesc =>
      'Tons de lentes personalizáveis para diferentes ambientes';

  @override
  String get simColorYellow => 'Amarelo';

  @override
  String get simColorAqua => 'Água-marinha';

  @override
  String get simColorBlue => 'Azul';

  @override
  String get simColorOrange => 'Laranja';

  @override
  String get simColorRed => 'Vermelho';

  @override
  String get activationTitle => 'Ativação do Dispositivo';

  @override
  String get activationEnterEmail =>
      'Por favor, digite seu e-mail para solicitar acesso.';

  @override
  String get activationEmailLabel => 'E-mail';

  @override
  String get activationRequestAccess => 'Solicitar Aceso';

  @override
  String get activationAwaitingApproval => 'Aguardando Aprovação';

  @override
  String activationPendingMessage(String email) {
    return 'Sua solicitação de ativação do dispositivo está aguardando aprovação.\nE-mail: $email';
  }

  @override
  String get activationRefreshStatus => 'Atualizar';

  @override
  String get activationConnectionRequired => 'Conexão Necessária';

  @override
  String get activationOfflineLimitReached => 'Limite de uso offline atingido.';

  @override
  String get activationRetryConnection => 'Tentar Novamente';

  @override
  String get activationErrorTitle => 'Erro';

  @override
  String get activationEmailInvalid => 'Por favor, insira um e-mail válido';

  @override
  String get activationRequestExists =>
      'Já existe uma solicitação para este e-mail.';

  @override
  String get activationNoInternet =>
      'Sem conexão com a internet e não ativado anteriormente.';

  @override
  String get activationConnectionTimeout =>
      'Tempo limite de conexão esgotado. Verifique sua internet.';

  @override
  String get nativeSplitGalleryOnlyHint =>
      'Toque no botão inferior para abrir a câmera\nou selecione uma foto da sua galeria';

  @override
  String get nativeSplitModeGallery => 'Galeria';

  @override
  String get nativeSplitModeCamera => 'Câmera';

  @override
  String get lensType => 'Tipo de Lente';

  @override
  String get simCatAspheric => 'Asférico';

  @override
  String get simCatAsphericDesc => 'Design de lente mais plano e estético';

  @override
  String get simCatBlueFilter => 'Filtro Luz Azul';

  @override
  String get simCatBlueFilterDesc =>
      'Proteção contra luz azul de telas digitais';

  @override
  String get simCatMonofocal => 'Monofocal';

  @override
  String get simCatMonofocalDesc => 'Correção visual com um único ponto focal';

  @override
  String get menuPhotoSync => 'Photo Sync';

  @override
  String get photoSyncTitle => 'Photo Sync';

  @override
  String get photoSyncSubtitle => 'Transferencia de fotos sem internet';

  @override
  String get photoSyncHost => 'TOTEM';

  @override
  String get photoSyncHostDesc => 'Este dispositivo recebe fotos';

  @override
  String get photoSyncClient => 'CELULAR';

  @override
  String get photoSyncClientDesc => 'Este dispositivo envia fotos';

  @override
  String get photoSyncScanQr => 'Escanear código QR';

  @override
  String get photoSyncAutoReconnect => 'Reconectar automaticamente';

  @override
  String get photoSyncConnected => 'Conectado ao totem';

  @override
  String get photoSyncTakePhoto => 'Tirar foto';

  @override
  String get photoSyncSending => 'Enviando foto...';

  @override
  String get photoSyncSent => 'Foto enviada!';

  @override
  String get photoSyncSendError => 'Erro ao enviar. Tente novamente.';

  @override
  String get photoSyncWaiting => 'Aguardando conexões...';

  @override
  String get photoSyncStarting => 'Iniciando ponto de acesso...';

  @override
  String get photoSyncStartingDesc => 'Isso pode levar alguns segundos';

  @override
  String get photoSyncReceivedPhotos => 'Fotos recebidas';

  @override
  String photoSyncDevicesConnected(int count) {
    return '$count dispositivo(s) conectado(s)';
  }

  @override
  String get photoSyncNoConnections => 'Aguardando conexões...';

  @override
  String get photoSyncRetry => 'Tentar novamente';

  @override
  String get photoSyncRoleHostActiveSubtitle =>
      'Sessão ativa – recebendo fotos';

  @override
  String get photoSyncRoleHostInactiveSubtitle =>
      'Este dispositivo recebe fotos';

  @override
  String get photoSyncRoleHostActiveDesc =>
      'Você pode usar o resto do app normalmente.\nAs fotos continuarão chegando em segundo plano.';

  @override
  String get photoSyncRoleHostInactiveDesc =>
      'Mostrará um código QR para outros\ndispositivos conectarem';

  @override
  String get photoSyncRoleClientTitle => 'CELULAR';

  @override
  String get photoSyncRoleClientSubtitle => 'Este dispositivo envia fotos';

  @override
  String get photoSyncRoleClientDesc =>
      'Escaneie o QR do totem para\nconectar e tirar fotos';

  @override
  String get photoSyncDisconnect => 'DESCONECTAR TOTEM';

  @override
  String photoSyncPhotosCount(int count) {
    return '$count fotos';
  }

  @override
  String get photoSyncRoleSubtitle => 'Sincronização de fotos';

  @override
  String get simSceneBuildingPositive => 'Edifício Positivo';

  @override
  String get simSceneBuildingNegative => 'Edifício Negativo';

  @override
  String get simSceneTextPositive => 'Leitura Positivo';

  @override
  String get simSceneTextNegative => 'Leitura Negativo';

  @override
  String get galleryTitle => 'Galeria';

  @override
  String get vmInternalGallery => 'Galeria Interna';

  @override
  String get cosmeticLensSaved => 'Imagem salva com sucesso!';

  @override
  String get cosmeticLensSaveError => 'Falha ao salvar a imagem';

  @override
  String get simSceneSmartphone => 'Celular';

  @override
  String get simSceneStore => 'Loja';

  @override
  String get simLensProgressive => 'Lente Progressiva';

  @override
  String get simLensNoLens => 'Sem Lente';

  @override
  String get saveMeasurement => 'SALVAR MEDIÇÃO';

  @override
  String get saveMeasurementDialogTitle => 'Salvar medição';

  @override
  String get saveToGallery => 'Galeria interna';

  @override
  String get saveToGalleryDesc => 'Salva foto e ângulo pantoscópico';

  @override
  String get saveToMeasurements => 'Medições';

  @override
  String get saveToMeasurementsDesc => 'Salva o estado completo para reeditar';

  @override
  String get patientData => 'Dados do paciente';

  @override
  String get patientFirstName => 'Nome';

  @override
  String get patientLastName => 'Sobrenome';

  @override
  String get optionalHint => 'Opcional';

  @override
  String get measurementSaved => 'Medição salva';

  @override
  String get photoSavedToGallery => 'Foto salva na galeria';

  @override
  String get myMeasurements => 'Minhas medições';

  @override
  String get noSavedMeasurements => 'Nenhuma medição salva';

  @override
  String get sortByDate => 'Por data';

  @override
  String get sortByName => 'Por nome';

  @override
  String get deleteMeasurementTitle => 'Excluir medição?';

  @override
  String get deleteMeasurementContent =>
      'Esta medição será excluída permanentemente.';

  @override
  String get unknownPatient => 'Paciente desconhecido';

  @override
  String get updateMeasurement => 'Atualizar medição';

  @override
  String get save => 'Salvar';

  @override
  String get hubNewMeasurement => 'Nova Medição';

  @override
  String get hubDetectorNotReady =>
      'O detector ainda não está pronto. Tente novamente.';

  @override
  String get hubAnalyzing => 'Analisando...';

  @override
  String heightTopShort(String value) {
    return 'Alt.sup: $value';
  }

  @override
  String get frameOuterW => 'Largura ext.';

  @override
  String get frameWidthField => 'Largura da armação';

  @override
  String get frameWidthHint => 'ex. 119';

  @override
  String get hubNoAccessory => 'Medição remota';

  @override
  String get frameWidthMissingWarning =>
      'Informe a largura da armação para calcular';

  @override
  String get cleanView => 'Vista limpa';

  @override
  String get linkLenses => 'Vincular lentes (espelhar ajustes)';

  @override
  String get homeBgTitle => 'Fundo';

  @override
  String get homeBgModeVideo1Loop => 'Vídeo 1 · movimento permanente';

  @override
  String get homeBgModeVideo2Loop => 'Vídeo 2 · movimento permanente';

  @override
  String get homeBgModeVideo3Loop => 'Vídeo 3 · movimento permanente';

  @override
  String get homeBgModeVideo1Periodic =>
      'Vídeo 1 · de tempos em tempos, e volta à imagem';

  @override
  String get homeBgModeVideo2Periodic =>
      'Vídeo 2 · de tempos em tempos, e volta à imagem';

  @override
  String get homeBgModeVideo3Periodic =>
      'Vídeo 3 · de tempos em tempos, e volta à imagem';

  @override
  String get homeBgModeStill => 'Somente imagem';

  @override
  String get homeBgInterval => 'Repetir a cada';

  @override
  String get homeBgGestures =>
      'Um toque: pausa / reproduz · Toque duplo: troca de vídeo · Manter: somente imagem';

  @override
  String get simAdaptLabel => 'Adaptação';

  @override
  String get simAdaptStandard => 'Padrão';

  @override
  String get simAdaptGood => 'Boa';

  @override
  String get simAdaptPremium => 'Premium';

  @override
  String get simReplay => 'Reproduzir';

  @override
  String get sinGlasses => 'Sem óculos';

  @override
  String get sharedView => 'Vista compartilhada';

  @override
  String get lensLabelA => 'Lente A';

  @override
  String get lensLabelB => 'Lente B';

  @override
  String get comparatorLabel => 'Comparador';

  @override
  String get settingsCopied => 'Configurações copiadas para B';

  @override
  String get copyAtoB => 'Copiar A para B';

  @override
  String get visagismoAnalyzing => 'Analisando o rosto…';

  @override
  String get visagismoCameraPermissionBody =>
      'Esta função precisa de permissão de câmera para funcionar. Ative-a nas configurações do dispositivo.';

  @override
  String get visagismoCameraStartFailed => 'Não foi possível iniciar a câmera.';

  @override
  String get visagismoCaptureFailed => 'Erro ao tirar a foto. Tente novamente.';

  @override
  String get visagismoConnectToTotem => 'Conectar ao Tótem';

  @override
  String visagismoConnectedTo(String totem) {
    return 'Conectado ao Tótem ($totem)';
  }

  @override
  String get visagismoDiagChin => 'Queixo (0 arredondado – 1 pontudo)';

  @override
  String get visagismoDiagConfidence => 'Confiança';

  @override
  String get visagismoDiagDetectorError => 'Erro do detector';

  @override
  String get visagismoDiagFootnote =>
      'As proporções são calculadas em pixels sobre o contorno do ML Kit, que vai até o meio da testa (não até a linha do cabelo). Os limites do classificador ainda não foram validados com rostos de referência.';

  @override
  String get visagismoDiagForeheadCheek => 'Testa / maçãs do rosto';

  @override
  String get visagismoDiagIssue => 'Problema';

  @override
  String get visagismoDiagJawAngle => 'Ângulo da mandíbula';

  @override
  String get visagismoDiagJawCheek => 'Mandíbula / maçãs do rosto';

  @override
  String get visagismoDiagNoData => 'Sem dados da última foto.';

  @override
  String get visagismoDiagPitch => 'Inclinação vertical (pitch)';

  @override
  String get visagismoDiagRoll => 'Inclinação lateral (roll)';

  @override
  String get visagismoDiagShape => 'Formato';

  @override
  String get visagismoDiagTitle => 'Medições (diagnóstico)';

  @override
  String get visagismoDiagWidthHeight => 'Largura / altura';

  @override
  String get visagismoDiagWidthHeightPx => 'Largura / altura (px)';

  @override
  String get visagismoDiagYaw => 'Giro da cabeça (yaw)';

  @override
  String visagismoFaceShapeName(String shape) {
    String _temp0 = intl.Intl.selectLogic(shape, {
      'redondo': 'Redondo',
      'cuadrado': 'Quadrado',
      'ovalado': 'Oval',
      'corazon': 'Coração',
      'diamante': 'Diamante',
      'alargado': 'Alongado',
      'other': '$shape',
    });
    return '$_temp0';
  }

  @override
  String visagismoFrameDetail(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'aviador_ultra_fino_de_metal': 'Fio dourado clássico',
      'aviador_de_acetato_clasico': 'Tartaruga',
      'aviador_grueso_vanguardista': 'Acetato preto marcante',
      'aviador_translucido_contemporaneo': 'Acetato champanhe',
      'aviador_industrial_moderno': 'Titânio preto fosco e misto',
      'other': '$id',
    });
    return '$_temp0';
  }

  @override
  String visagismoFrameName(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'aviador_ultra_fino_de_metal': 'Aviador ultrafino de metal',
      'aviador_de_acetato_clasico': 'Aviador de acetato clássico',
      'aviador_grueso_vanguardista': 'Aviador grosso vanguardista',
      'aviador_translucido_contemporaneo': 'Aviador translúcido contemporâneo',
      'aviador_industrial_moderno': 'Aviador industrial moderno',
      'cat_eye_ultra_fino_de_metal': 'Cat-eye ultrafino de metal',
      'cat_eye_de_acetato_clasico': 'Cat-eye de acetato clássico',
      'cat_eye_grueso_vanguardista': 'Cat-eye grosso vanguardista',
      'cat_eye_translucido_contemporaneo': 'Cat-eye translúcido contemporâneo',
      'cat_eye_doble_puente_industrial': 'Cat-eye ponte dupla industrial',
      'rectangular_ultra_fino_de_metal': 'Retangular ultrafino de metal',
      'cuadrado_de_acetato_clasico': 'Quadrado de acetato clássico',
      'rectangular_grueso_vanguardista': 'Retangular grosso vanguardista',
      'cuadrado_translucido_contemporaneo':
          'Quadrado translúcido contemporâneo',
      'doble_puente_industrial': 'Ponte dupla industrial',
      'ovalado_ultra_fino_de_metal': 'Oval ultrafino de metal',
      'ovalado_de_acetato_clasico': 'Oval de acetato clássico',
      'ovalado_grueso_vanguardista': 'Oval grosso vanguardista',
      'ovalado_translucido_contemporaneo': 'Oval translúcido contemporâneo',
      'ovalado_doble_puente_industrial': 'Oval ponte dupla industrial',
      'wayfarer_ultra_fino_de_metal': 'Wayfarer ultrafino de metal',
      'wayfarer_de_acetato_clasico': 'Wayfarer de acetato clássico',
      'wayfarer_grueso_vanguardista': 'Wayfarer grosso vanguardista',
      'wayfarer_translucido_contemporaneo':
          'Wayfarer translúcido contemporâneo',
      'wayfarer_doble_puente_industrial': 'Wayfarer ponte dupla industrial',
      'other': '$id',
    });
    return '$_temp0';
  }

  @override
  String get visagismoFrontCamera => 'Câmera frontal';

  @override
  String get visagismoIssueDetectorError =>
      'Não foi possível analisar a foto: o detector de rostos falhou. Tente novamente; se continuar, avise o suporte (mantenha pressionada esta mensagem para ver o detalhe técnico).';

  @override
  String get visagismoIssueHeadTilted =>
      'O queixo está muito para cima ou para baixo. Peça para olhar para a frente, na altura da câmera.';

  @override
  String get visagismoIssueHeadTurned =>
      'O rosto está virado. Peça para olhar de frente para a câmera.';

  @override
  String get visagismoIssueNoFace => 'Nenhum rosto foi detectado na foto.';

  @override
  String get visagismoMatchGood => 'Muito bom';

  @override
  String get visagismoMatchIdeal => 'Ideal';

  @override
  String get visagismoMatchNotRecommended => 'Não recomendado';

  @override
  String get visagismoMatchPossible => 'Possível';

  @override
  String get visagismoNoCamera =>
      'Nenhuma câmera disponível foi detectada neste dispositivo. O visagismo precisa de uma câmera para funcionar.';

  @override
  String get visagismoNoFrames => 'Ainda não há armações disponíveis.';

  @override
  String get visagismoOpenSettings => 'Abrir configurações';

  @override
  String get visagismoPhotoSaved => 'Foto salva na galeria interna';

  @override
  String visagismoPhotoSavedAndSent(String totem) {
    return 'Foto salva e enviada ao Tótem ($totem)';
  }

  @override
  String get visagismoPhotoSendFailed =>
      'Foto salva na galeria · não foi possível enviá-la ao Tótem';

  @override
  String get visagismoRearCamera => 'Câmera traseira';

  @override
  String get visagismoRecenterFrame => 'Reposicionar a armação';

  @override
  String get visagismoRetake => 'Repetir';

  @override
  String get visagismoRetry => 'Tentar novamente';

  @override
  String get visagismoPickPhotoTitle => 'Escolha uma foto do cliente';

  @override
  String get visagismoPickPhotoHint =>
      'De frente, com boa luz e sem óculos. Ao escolhê-la, o rosto é escaneado e as armações são provadas.';

  @override
  String get visagismoInternalGallery => 'Galeria interna';

  @override
  String get visagismoDeviceGallery => 'Galeria do dispositivo';

  @override
  String get visagismoGalleryEmpty => 'Ainda não há fotos na galeria interna';

  @override
  String get visagismoPickFailed => 'Não foi possível abrir a foto';

  @override
  String get visagismoPickAnother => 'Escolher outra foto';

  @override
  String get visagismoFrameOpacity => 'Opacidade da armação';

  @override
  String get visagismoFrameShadow => 'Sombra da armação';

  @override
  String get visagismoSaveWithFrame => 'Salvar com armação';

  @override
  String get visagismoSendWithFrame => 'Enviar com armação';

  @override
  String get visagismoTitle => 'Visagismo';

  @override
  String get visagismoTryOnSaveFailed =>
      'Não foi possível salvar a foto com a armação';

  @override
  String visagismoTryOnSaved(String frame) {
    return 'Foto com $frame salva na galeria';
  }

  @override
  String visagismoTryOnSent(String frame) {
    return 'Foto com $frame enviada ao Tótem';
  }
}
