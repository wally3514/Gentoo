# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-libs/daq/daq-0.5.ebuild,v 1.2 2011/01/14 22:39:38 hwoarang Exp $

EAPI="2"

inherit eutils multilib autotools

DESCRIPTION="Data Acquisition library, for packet I/O"
HOMEPAGE="http://www.snort.org/"
SRC_URI="http://www.snort.org/downloads/630 -> ${P}.tar.gz"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 ~x86"
IUSE="ipv6 +afpacket +dump +pcap nfq ipq static-libs"

DEPEND="pcap? ( >=net-libs/libpcap-1.0.0 )
		dump? ( >=net-libs/libpcap-1.0.0 )
		nfq? ( dev-libs/libdnet
			>=net-firewall/iptables-1.4.10
			net-libs/libnetfilter_queue )
		ipq? ( dev-libs/libdnet
			>=net-firewall/iptables-1.4.10
			net-libs/libnetfilter_queue )"

RDEPEND="${DEPEND}"

src_prepare() {
	einfo "Applying PCAP buffer size fix."
	if use pcap; then
		sed -i -e 's:strtol(entry->key:strtol(entry->value:g' \
			"${WORKDIR}/${P}/os-daq-modules/daq_pcap.c"	\
			|| die "PCAP buffer size fix failed"
	fi
	eautoreconf
}

src_configure() {
	econf \
		$(use_enable ipv6) \
		$(use_enable pcap pcap-module) \
		$(use_enable afpacket afpacket-module) \
		$(use_enable dump dump-module) \
		$(use_enable nfq nfq-module) \
		$(use_enable ipq ipq-module) \
		$(use_enable static-libs static) \
		--disable-ipfw-module \
		--disable-bundled-modules
}

src_install() {
	emake -j1 DESTDIR="${D}" install || die "make install failed"
	dodoc ChangeLog README
	for x in pcap afpacket dump nfq ipq; do
		if use $x; then
			echo "removing executable bit: /usr/$(get_libdir)/daq/daq_$x.la"
			fperms -x "/usr/$(get_libdir)/daq/daq_$x.la" || die
		fi
	done
}

pkg_postinst() {
	elog "The Data Acquisition library (DAQ) for packet I/O replaces direct"
	elog "calls to PCAP functions with an abstraction layer that facilitates"
	elog "operation on a variety of hardware and software interfaces without"
	elog "requiring changes to application such as Snort."
	elog
	elog "The only DAQ modules supported with this ebuild are AFpacket, PCAP,"
	elog "and Dump. IPQ and NFQ will be supported in future versions of this"
	elog "package."
	elog
	elog "Please see the README file for DAQ for information about specific"
	elog "DAQ modules."
	ewarn
	ewarn "If you are reinstalling this package, you should also reinstall"
	ewarn "packages that use this library for packet capture."
}
