# Maintainer: nullstacked
pkgname=kvmd-restart
pkgver=1.0.3
pkgrel=1
pkgdesc="Floating restart-PiKVM-OS button for PiKVM Web UI"
arch=('any')
url="https://github.com/nullstacked/kvmd-restart"
license=('GPL3')
depends=('kvmd' 'sudo')
install=kvmd-restart.install

package() {
    install -Dm755 "$srcdir/../files/apply-patches.sh" "$pkgdir/usr/share/kvmd-restart/apply-patches.sh"
    install -Dm644 "$srcdir/../files/restart.css" "$pkgdir/usr/share/kvmd-restart/restart.css"
    install -Dm644 "$srcdir/../files/kvmd-restart.yaml" "$pkgdir/etc/kvmd/override.d/kvmd-restart.yaml"
    install -Dm440 "$srcdir/../files/sudoers" "$pkgdir/etc/sudoers.d/kvmd-restart"
    install -Dm644 "$srcdir/../kvmd-restart.hook" "$pkgdir/etc/pacman.d/hooks/kvmd-restart.hook"
}
