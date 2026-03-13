class AppEnv {
  AppEnv._();

  static const String pocketBaseUrl = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: 'http://127.0.0.1:8090',
  );

  static const String midtransServerKey = String.fromEnvironment(
    'MIDTRANS_SERVER_KEY',
    defaultValue: '',
  );

  static const String midtransClientKey = String.fromEnvironment(
    'MIDTRANS_CLIENT_KEY',
    defaultValue: '',
  );

  static const String midtransMerchantId = String.fromEnvironment(
    'MIDTRANS_MERCHANT_ID',
    defaultValue: '',
  );

  static const String databaseHost = String.fromEnvironment(
    'DB_HOST',
    defaultValue: '',
  );

  static const String databasePort = String.fromEnvironment(
    'DB_PORT',
    defaultValue: '',
  );

  static const String databaseName = String.fromEnvironment(
    'DB_NAME',
    defaultValue: '',
  );

  static const String databaseUser = String.fromEnvironment(
    'DB_USER',
    defaultValue: '',
  );

  static const String databasePassword = String.fromEnvironment(
    'DB_PASSWORD',
    defaultValue: '',
  );
}
