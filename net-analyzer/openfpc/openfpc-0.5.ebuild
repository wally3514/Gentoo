# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=3

inherit webapp depend.php

REV="281"
DESCRIPTION="A full-packet network traffic recorder & buffering system"
HOMEPAGE="http://www.openfpc.org/"
SRC_URI="http://openfpc.googlecode.com/files/${P}-${REV}.tgz"

LICENSE="GPL-2"
KEYWORDS="~amd64"
IUSE=""

RDEPEND="dev-lang/perl
	dev-perl/Date-Simple
	dev-perl/Filesys-Df
	dev-perl/TermReadKey
	dev-perl/Archive-Zip
	dev-perl/DateTime
	dev-perl/DBI
	net-analyzer/tcpdump
	net-analyzer/wireshark
	>=net-analyzer/daemonlogger-1.2.1
	dev-lang/php[mysql]"

need_httpd_cgi
need_php_httpd

S="${WORKDIR}/${P}-${REV}"

pkg_setup() {
	webapp_pkg_setup
}

src_install() {
	webapp_src_preinst
	dodir /etc/openfpc \
		${S}/$(get_libdir) \
		/var/log/openfpc || die
	insinto /etc/openfpc || die
	newins etc/openfpc-default.conf openfpc.conf ||die
	dodoc docs/INSTALL \
		docs/README \
		docs/TODO \
		etc/openfpc-example-proxy.conf \
		etc/openfpc.apache2.site \
		etc/routes.ofpc || die
	dobin openfpc \
		openfpc-client \
		openfpc-cx2db \
		openfpc-dbmaint \
		openfpc-queued || die
	insinto "${MY_HTDOCSDIR}" || die
	doins www/bluegrade.png www/index.php || die
	insinto "${MY_CGIBINDIR}" || die
	doins cgi-bin/extract.cgi || die
#	webapp_postinst_txt en "${FILESDIR}"/postinstall-en-3.1.txt
	webapp_src_install
}
