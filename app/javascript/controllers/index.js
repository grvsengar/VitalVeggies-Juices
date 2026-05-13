import { application } from "controllers/application"
import MobileMenuController from "controllers/mobile_menu_controller"
import StorefrontController from "controllers/storefront_controller"
import MarketPulseController from "controllers/market_pulse_controller"
import TiltCardController from "controllers/tilt_card_controller"
import AddToCartController from "controllers/add_to_cart_controller"

application.register("mobile-menu", MobileMenuController)
application.register("storefront", StorefrontController)
application.register("market-pulse", MarketPulseController)
application.register("tilt-card", TiltCardController)
application.register("add-to-cart", AddToCartController)

if (document.querySelector('[data-controller~="command-palette"]')) {
  import("controllers/command_palette_controller").then(({ default: controller }) => {
    application.register("command-palette", controller)
  })
}

if (document.querySelector('[data-controller~="chart"]')) {
  import("controllers/chart_controller").then(({ default: controller }) => {
    application.register("chart", controller)
  })
}

if (document.querySelector('[data-controller~="ffmpeg-studio"]')) {
  import("controllers/ffmpeg_studio_controller").then(({ default: controller }) => {
    application.register("ffmpeg-studio", controller)
  })
}
