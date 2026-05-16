require "test_helper"

class PwaInstallTest < ActionDispatch::IntegrationTest
  test "GET /manifest.webmanifest serves a valid PWA manifest" do
    get "/manifest.webmanifest"
    assert_response :success

    manifest = JSON.parse(response.body)

    assert_equal Brand::NAME, manifest["name"]
    assert_equal Brand::NAME, manifest["short_name"]
    assert_equal "/", manifest["start_url"]
    assert_equal "standalone", manifest["display"]
    assert manifest["background_color"].present?, "background_color must be set"
    assert manifest["theme_color"].present?, "theme_color must be set"

    sizes = manifest["icons"].map { |i| i["sizes"] }
    assert_includes sizes, "192x192"
    assert_includes sizes, "512x512"
  end

  test "GET /service-worker.js serves a JavaScript service worker" do
    get "/service-worker.js"
    assert_response :success
    assert_match %r{javascript|ecmascript}, response.media_type
    assert_match(/addEventListener\(\s*["']fetch["']/, response.body,
      "service worker must declare a fetch handler for installability")
  end

  test "sign-in page links the manifest and includes iOS PWA meta tags" do
    get "/session/new"
    assert_response :success

    assert_select "link[rel=manifest][href='/manifest.webmanifest']"
    assert_select "link[rel='apple-touch-icon']"
    assert_select "meta[name='apple-mobile-web-app-capable'][content='yes']"
    assert_select "meta[name='apple-mobile-web-app-status-bar-style']"
    assert_select "meta[name='theme-color']"
  end
end
