# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-analyzer/barnyard2/barnyard2-1.8.ebuild,v 1.3 2010/06/17 21:44:24 patrick Exp $

EAPI="2"

DESCRIPTION="Parser for Snort unified/unified2 files"
HOMEPAGE="http://www.securixlive.com/barnyard2/"
SRC_URI="http://www.securixlive.com/download/barnyard2/${P}.tar.gz"
SLOT="0"
LICENSE="GPL-2"
KEYWORDS="~amd64 ~x86"
IUSE="static debug aruba gre mpls prelude ipv6 mysql odbc postgres"

DEPEND="virtual/libpcap
        mysql? ( virtual/mysql )
        postgres? ( dev-db/postgresql-server )
        prelude? ( >=dev-libs/libprelude-0.9.0 )
        odbc? ( dev-db/unixODBC )"

src_prepare() {
	sed -i -e "s:^#config interface:config interface:" \
		"${WORKDIR}/${P}/etc/barnyard2.conf" || die
	sed -i -e "s:^output alert_fast:#output alert_fast:" \
		"${WORKDIR}/${P}/etc/barnyard2.conf" || die
}

src_configure() {
	econf \
		$(use_enable !static shared) \
		$(use_enable static) \
		$(use_enable debug) \
		$(use_enable aruba) \
		$(use_enable gre) \
		$(use_enable mpls) \
		$(use_enable prelude) \
		$(use_enable ipv6) \
		$(use_with mysql) \
		$(use_with odbc) \
		$(use_with postgres postgresql) \
		--without-oracle \
		--disable-bro || die
	emake || die
}

src_install () {
	make DESTDIR="${D}" install || die
	newconfd "${FILESDIR}/barnyard2.confd" barnyard2 || die
	newinitd "${FILESDIR}/barnyard2.initd" barnyard2 || die
	dodir /etc/barnyard2 \
		/var/log/snort \
		/var/log/snort/archive \
		/var/log/barnyard2 || die
	dodoc LICENSE \
		RELEASE.NOTES \
		etc/barnyard2.conf \
		doc/README* \
		schemas/create_* || die
	rm "${D}"/etc/barnyard2.conf || die
}

pkg_postinst() {
	elog "Configuration options can be set in /etc/conf.d/barnyard2."
	elog
	elog "An example configuration file can be found in /usr/share/doc/${PF}."
}
