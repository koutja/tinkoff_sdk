/*

  Copyright © 2020 ProgressiveMobile

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

part of tinkoff_sdk;

class TinkoffSdk {
  static TinkoffSdk? _instance;

  factory TinkoffSdk() {
    if (_instance == null) {
      _instance = TinkoffSdk._private(const MethodChannel(Method.channel));
    }
    return _instance!;
  }

  TinkoffSdk._private(this._channel);

  final MethodChannel _channel;
  String? _terminalKey;

  bool get activated => _terminalKey != null;

  /// Создание объекта для взаимодействия с SDK и передача данных продавца.
  /// Данные для активации выдаются в личном кабинете после подключения к ​Интернет-Эквайрингу.​
  ///
  /// [terminalKey] - Терминал Продавца.
  /// [password] - Пароль от терминала.
  /// [publicKey] - Публичный ключ. Используется для шифрования данных.
  ///               Необходим для интеграции вашего приложения с интернет-эквайрингом Тинькофф.
  ///
  /// Флаги ниже используются для тестирования настроек эквайринга:
  /// [isDeveloperMode] - Тестовый URL (в этом режиме деньги с карт не списываются).
  /// [logging] - Логирование запросов.
  Future<bool> activate({
    required String terminalKey,
    required String password,
    required String publicKey,
    bool isDeveloperMode = false,
    bool logging = false,
  }) async {
    final method = Method.activate;

    final arguments = <String, dynamic>{
      method.terminalKey: terminalKey,
      method.password: password,
      method.publicKey: publicKey,
      method.isDeveloperMode: isDeveloperMode,
      method.logging: logging,
    };

    final activated =
        await _channel.invokeMethod<bool>(method.name, arguments) ?? false;

    if (activated)
      _terminalKey = terminalKey;
    else
      throw 'Cannot activate TinkoffSDK.'
          '\nOne or more of parameters are invalid.';

    return activated;
  }

  Future<List<CardData>> getCardList(String customerKey) async {
    _checkActivated();

    final method = Method.getCardList;

    final arguments = <String, dynamic>{
      method.customerKey: customerKey,
    };

    return _channel
        .invokeMethod(method.name, arguments)
        .then(parseCardListResult);
  }

  /// Открытие экрана оплаты.
  /// Возвращает [true] при успешной оплате, а
  /// в случае ошибки либо отмены вернет [false].
  ///
  /// Подробное описание параметров см. в реализации
  /// [OrderOptions], [CustomerOptions], [FeaturesOptions], [Receipt].
  Future<TinkoffResult> openPaymentScreen({
    required String terminalKey,
    required String publicKey,
    required OrderOptions orderOptions,
    required CustomerOptions customerOptions,
    FeaturesOptions featuresOptions = const FeaturesOptions(),
    AndroidReceipt? androidReceipt,
    IosReceipt? iosReceipt,
  }) async {
    _checkActivated();

    final method = Method.openPaymentScreen;
    String? ffdVersion;
    if (androidReceipt?.runtimeType == AndroidReceiptFfd105) {
      ffdVersion = "105";
    } else if (androidReceipt?.runtimeType == AndroidReceiptFfd12) {
      ffdVersion = "12";
    }

    final arguments = <String, dynamic>{
      method.orderOptions: orderOptions.arguments,
      method.customerOptions: customerOptions._arguments,
      method.featuresOptions: featuresOptions._arguments(),
      method.receipt: Platform.isIOS ? iosReceipt?.arguments : androidReceipt?.arguments,
      method.terminalKey: terminalKey,
      method.publicKey: publicKey,
      method.ffdVersion: ffdVersion,
    };

    return _channel
        .invokeMethod(method.name, arguments)
        .then(parseTinkoffResult);
  }

  /// Открытие экрана привязки карт.
  ///
  /// Подробное описание параметров см. в реализации
  /// [CustomerOptions], [FeaturesOptions].
  Future<void> openAttachCardScreen({
    required CustomerOptions customerOptions,
    FeaturesOptions featuresOptions = const FeaturesOptions(),
  }) async {
    _checkActivated();

    final method = Method.attachCardScreen;

    final arguments = <String, dynamic>{
      method.customerOptions: customerOptions._arguments,
      method.featuresOptions: featuresOptions._arguments()
    };

    return _channel.invokeMethod(method.name, arguments);
  }

  /// Отображает экран с многоразовым `QR-кодом`, отсканировав который,
  /// пользователь сможет провести оплату с помощью `Системы быстрых платежей`
  ///
  /// При данном типе оплаты SDK никак не отслеживает статус платежа,
  /// соответственно [Completer] завершается только при ошибке либо отмене (закрытии экрана).
  Future<void> showStaticQRCode() async {
    _checkActivated();
    final method = Method.showStaticQrScreen;

    return _channel.invokeMethod(method.name).then(parseTinkoffResult);
  }

  /// Отображает экран с одноразовым `QR-кодом`, отсканировав который,
  /// пользователь сможет провести оплату  с помощью `Системы быстрых платежей`
  ///
  /// При данном типе оплаты сумма и информация о платеже фиксируется,
  /// и SDK способен получить и обработать статус платежа
  Future<TinkoffResult> showDynamicQRCode({
    required PaymentFlow paymentFlow,
    OrderOptions? orderOptions,
    required CustomerOptions customerOptions,
    String? paymentId,
    int? amount,
    String? orderId,
  }) async {
    assert(
      (paymentFlow != PaymentFlow.full || orderOptions == null) ^
          (paymentFlow != PaymentFlow.finish ||
              paymentId == null ||
              amount == null ||
              orderId == null),
      """Для paymentFlow == PaymentFlow.full параметр orderOptions должен быть не null.
      Для paymentFlow == PaymentFlow.finish параметры paymentId, amount и orderID
      должны быть не null.""",
    );

    _checkActivated();
    final method = Method.showDynamicQrScreen;

    final arguments = <String, dynamic>{
      method.paymentFlow: paymentFlow.name,
      method.orderOptions: orderOptions?.arguments,
      method.customerOptions: customerOptions._arguments,
      method.paymentId: paymentId,
      method.amount: amount,
      method.orderId: orderId,
    };

    return _channel
        .invokeMethod(method.name, arguments)
        .then(parseTinkoffResult);
  }

  // TODO: implement Charge
  Future<TinkoffResult> startCharge() async {
    _checkActivated();
    final method = Method.startCharge;

    final arguments = <String, dynamic>{};

    return _channel
        .invokeMethod(method.name, arguments)
        .then(parseTinkoffResult);
  }

  void _checkActivated() {
    if (_terminalKey == null) {
      throw 'TinkoffSDK is not activated.'
          '\nYou need call TinkoffSdk.activate method before calling other methods.';
    }
  }
}
