//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_plugin.h>
#include <flutter_thermal_printer/flutter_thermal_printer_plugin_c_api.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>
#include <printing/printing_plugin.h>
#include <screen_retriever_windows/screen_retriever_windows_plugin_c_api.h>
#include <window_manager/window_manager_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterPosPrinterPlatformPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterPosPrinterPlatformPlugin"));
  FlutterThermalPrinterPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterThermalPrinterPluginCApi"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
  PrintingPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PrintingPlugin"));
  ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ScreenRetrieverWindowsPluginCApi"));
  WindowManagerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowManagerPlugin"));
}
