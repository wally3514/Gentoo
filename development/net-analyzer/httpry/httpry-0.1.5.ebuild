# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=3
inherit eutils

DESCRIPTION="Packet sniffer designed for logging HTTP traffic"
HOMEPAGE="http://dumpsterventures.com/jason/httpry/"
SRC_URI="http://dumpsterventures.com/jason/httpry/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"
IUSE="logrotate"

DEPEND="net-libs/libpcap
	logrotate? ( app-admin/logrotate )"
RDEPEND="${DEPEND}"

pkg_setup() {
	enewuser httpry
}

src_prepare() {
	sed -i -e "s:-Wall -O3 -funroll-loops:${CFLAGS}:g" \
		"${WORKDIR}/${P}/Makefile" || die
}

src_install() {
	# make install has issues so we do this manually
	dosbin httpry || die
	doman httpry.1 || die
	dodir /var/log/httpry || die
	fowners httpry /var/log/httpry || die
	dodoc doc/ChangeLog \
		doc/README \
		doc/format-string \
		doc/method-string \
		doc/perl-tools ||die
	docinto scripts
	dodoc scripts/parse_log.pl || die
	docinto scripts/plugins
	dodoc scripts/plugins/* || die
	newinitd ${FILESDIR}/httpry.rc.1 httpry
	newconfd ${FILESDIR}/httpry.confd.1 httpry

	if use logrotate; then
		insinto etc/logrotate.d/
		newins ${FILESDIR}/httpry.rotate httpry
	fi
}

pkg_postinst() {
	einfo "Please see /etc/conf.d/httpry for configuration options."
}
