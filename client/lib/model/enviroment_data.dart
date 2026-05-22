class EnvironmentData {
  final double temperature;
  final double humidity;
  final double dustUg;
  final double gasPpm;
  final bool autoMode;
  final int fanLevel;

  EnvironmentData({
    this.temperature = 0.0,
    this.humidity = 0.0,
    this.dustUg = 0.0,
    this.gasPpm = 0.0,
    this.autoMode = true,
    this.fanLevel = 1,
  });

  // Factory map JSON từ cấu trúc mảng 2 chiều của ThingsBoard
  // Truyền kèm `currentData` để giữ lại các thông số cũ nếu JSON mới không chứa chúng
  factory EnvironmentData.fromThingsBoard(
    Map<String, dynamic> dataObj,
    EnvironmentData currentData,
  ) {
    double temp = currentData.temperature;
    double hum = currentData.humidity;
    double dust = currentData.dustUg;
    double gas = currentData.gasPpm;
    bool autoMode = currentData.autoMode;
    int fanLevel = currentData.fanLevel;

    // Parse Nhiệt độ
    if (dataObj.containsKey('temperature')) {
      // Lấy phần tử [0][1] chính là giá trị "30.2", phần tử [0][0] là thời gian
      final val = dataObj['temperature'][0][1];
      temp = double.tryParse(val.toString()) ?? temp;
    }

    // Parse Độ ẩm
    if (dataObj.containsKey('humidity')) {
      final val = dataObj['humidity'][0][1];
      hum = double.tryParse(val.toString()) ?? hum;
    }

    // Parse Bụi (đảm bảo key giống với key bạn đẩy lên từ ESP32)
    if (dataObj.containsKey('dust_ug')) {
      final val = dataObj['dust_ug'][0][1];
      dust = double.tryParse(val.toString()) ?? dust;
    }

    // Parse Khí Gas
    if (dataObj.containsKey('gas_ppm')) {
      final val = dataObj['gas_ppm'][0][1];
      gas = double.tryParse(val.toString()) ?? gas;
    }

    // Parse Auto Mode
    if (dataObj.containsKey('auto_mode')) {
      final val = dataObj['auto_mode'][0][1];
      autoMode = val == true || val == 'true';
    }

    // Parse Fan Level
    if (dataObj.containsKey('fan_level')) {
      final val = dataObj['fan_level'][0][1];
      fanLevel = int.tryParse(val.toString()) ?? fanLevel;
      fanLevel = fanLevel.clamp(1, 3);
    }

    return EnvironmentData(
      temperature: temp,
      humidity: hum,
      dustUg: dust,
      gasPpm: gas,
      autoMode: autoMode,
      fanLevel: fanLevel,
    );
  }
}
