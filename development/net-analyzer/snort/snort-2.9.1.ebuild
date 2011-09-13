# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-analyzer/snort/snort-2.9.0.5.ebuild,v 1.3 2011/07/24 12:12:57 xarthisius Exp $

EAPI="2"
inherit eutils autotools multilib

DESCRIPTION="The de facto standard for intrusion detection/prevention"
HOMEPAGE="http://www.snort.org/"
SRC_URI="http://www.snort.org/downloads/867 -> ${P}.tar.gz"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~ppc ~ppc64 ~sparc ~x86"
IUSE="static +dynamicplugin +zlib +gre +mpls +targetbased +decoder-preprocessor-rules
+ppm +perfprofiling linux-smp-stats inline-init-failopen +threads debug +active-response 
+normalizer reload-error-restart +react +flexresp3 +paf large-pcap-64bit 
aruba mysql odbc postgres selinux"

DEPEND=">=net-libs/libpcap-1.0.0
	>=net-libs/daq-0.5
	>=dev-libs/libpcre-6.0
	dev-libs/libdnet
	postgres? ( dev-db/postgresql-base )
	mysql? ( virtual/mysql )
	odbc? ( dev-db/unixODBC )
	prelude? ( >=dev-libs/libprelude-0.9.0 )
	zlib? ( sys-libs/zlib )"

RDEPEND="${DEPEND}
	selinux? ( sec-policy/selinux-snort )"

pkg_setup() {

	if use zlib && ! use dynamicplugin; then
		eerror "You have enabled the 'zlib' USE flag but not the 'dynamicplugin' USE flag."
		eerror "'zlib' requires 'dynamicplugin' be enabled."
		die
	fi

	# pre_inst() is a better place to put this
	# but we need it here for the 'fowners' statements in src_install()
	enewgroup snort
	enewuser snort -1 -1 /dev/null snort

}

src_prepare() {

	#Multilib fix for the sf_engine
	einfo "Applying multilib fix."
	sed -i -e 's:${exec_prefix}/lib:${exec_prefix}/'$(get_libdir)':g' \
		"${WORKDIR}/${P}/src/dynamic-plugins/sf_engine/Makefile.am" \
		|| die "sed for sf_engine failed"

	#Multilib fix for the curent set of dynamic-preprocessors
	for i in ftptelnet smtp ssh dns ssl dcerpc2 sdf imap pop rzb_saac sip; do
		sed -i -e 's:${exec_prefix}/lib:${exec_prefix}/'$(get_libdir)':g' \
			"${WORKDIR}/${P}/src/dynamic-preprocessors/$i/Makefile.am" \
			|| die "sed for $i failed."
	done

	AT_M4DIR=m4 eautoreconf
}

src_configure() {

	econf \
		$(use_enable !static shared) \
		$(use_enable static) \
		$(use_enable dynamicplugin) \
		$(use_enable ipv6) \
		$(use_enable zlib) \
		$(use_enable gre) \
		$(use_enable mpls) \
		$(use_enable targetbased) \
		$(use_enable decoder-preprocessor-rules) \
		$(use_enable ppm) \
		$(use_enable perfprofiling) \
		$(use_enable linux-smp-stats) \
		$(use_enable inline-init-failopen) \
		$(use_enable threads pthread) \
		$(use_enable debug) \
		$(use_enable debug debug-msgs) \
		$(use_enable debug corefiles) \
		$(use_enable !debug dlclose) \
		$(use_enable active-response) \
		$(use_enable normalizer) \
		$(use_enable reload-error-restart) \
		$(use_enable react) \
		$(use_enable flexresp3) \
		$(use_enable paf) \
		$(use_enable large-pcap-64bit large-pcap) \
		$(use_enable aruba) \
		$(use_with mysql) \
		$(use_with odbc) \
		$(use_with postgres postgresql) \
		--enable-ipv6 \
		--enable-reload \
		--disable-prelude \
		--disable-build-dynamic-examples \
		--disable-profile \
		--disable-ppm-test \
		--disable-intel-soft-cpm \
		--disable-static-daq \
		--disable-rzb-saac \
		--without-oracle

}

src_install() {

	emake DESTDIR="${D}" install || die "emake failed"

	dodir /var/log/snort \
		/var/run/snort \
		/etc/snort/rules \
		/usr/$(get_libdir)/snort_dynamicrules \
			|| die "Failed to create core directories"

	# config.log and build.log are needed by Sourcefire
	# to trouble shoot build problems and bug reports so we are
	# perserving them incase the user needs upstream support.
	dodoc RELEASE.NOTES ChangeLog \
		doc/* \
		tools/u2boat/README.u2boat \
		schemas/* || die "Failed to install snort docs"

	insinto /etc/snort
	doins etc/attribute_table.dtd \
		etc/classification.config \
		etc/gen-msg.map \
		etc/reference.config \
		etc/threshold.conf \
		etc/unicode.map || die "Failed to install docs in etc"

	# We use snort.conf.distrib because the config file is complicated
	# and the one shipped with snort can change drastically between versions.
	# Users should migrate setting by hand and not with etc-update.
	newins etc/snort.conf snort.conf.distrib \
		|| die "Failed to add snort.conf.distrib"

	# config.log and build.log are needed by Sourcefire
	# to troubleshoot build problems and bug reports so we are
	# perserving them incase the user needs upstream support.
	# 'die' was intentionally not added here.
	if [ -f "${WORKDIR}/${PF}/config.log" ]; then
		dodoc "${WORKDIR}/${PF}/config.log"
	fi
	if [ -f "${T}/build.log" ]; then
		dodoc "${T}/build.log"
	fi

	insinto /etc/snort/preproc_rules
	doins preproc_rules/decoder.rules \
		preproc_rules/preprocessor.rules \
		preproc_rules/sensitive-data.rules || die "Failed to install preproc rule files"

	chown -R snort:snort \
		"${D}"/var/log/snort \
		"${D}"/var/run/snort \
		"${D}"/etc/snort \
		"${D}"/etc/snort/preproc_rules || die "Failed to set ownership of dirs"

	newinitd "${FILESDIR}/snort.rc10" snort || die "Failed to install snort init script"
	newconfd "${FILESDIR}/snort.confd" snort || die "Failed to install snort confd file"

	# Sourcefire uses Makefiles to install docs causing Bug #297190.
	# This removes the unwanted doc directory and rogue Makefiles.
	rm -rf "${D}"usr/share/doc/snort || die "Failed to remove SF doc directories"
	rm "${D}"usr/share/doc/"${PF}"/Makefile* || die "Failed to remove doc make files"

	# Set the correct lib path for dynamicengine, dynamicpreprocessor, and dynamicdetection
	sed -i -e 's:/usr/local/lib:/usr/'$(get_libdir)':g' \
		"${D}etc/snort/snort.conf.distrib" \
		|| die "Failed to update snort.conf.distrib lib paths"

	# Set the correct rule location in the config
	sed -i -e 's:RULE_PATH ../rules:RULE_PATH /etc/snort/rules:g' \
		"${D}etc/snort/snort.conf.distrib" \
		|| die "Failed to update snort.conf.distrib rule path"

	# Set the correct preprocessor/decoder rule location in the config
	sed -i -e 's:PREPROC_RULE_PATH ../preproc_rules:PREPROC_RULE_PATH /etc/snort/preproc_rules:g' \
		"${D}etc/snort/snort.conf.distrib" \
		|| die "Failed to update snort.conf.distrib preproc rule path"

	# Enable the preprocessor/decoder rules
	sed -i -e 's:^# include $PREPROC_RULE_PATH:include $PREPROC_RULE_PATH:g' \
		"${D}etc/snort/snort.conf.distrib" \
		|| die "Failed to uncomment snort.conf.distrib preproc rule path"

	sed -i -e 's:^# dynamicdetection directory:dynamicdetection directory:g' \
		"${D}etc/snort/snort.conf.distrib" \
		|| die "Failed to uncomment snort.conf.distrib dynamicdetection directory"

	# Just some clean up of trailing /'s in the config
	sed -i -e 's:snort_dynamicpreprocessor/$:snort_dynamicpreprocessor:g' \
		"${D}etc/snort/snort.conf.distrib" \
		|| die "Failed to clean up snort.conf.distrib trailing slashes"

	# Make it clear in the config where these are...
	sed -i -e 's:^include classification.config:include /etc/snort/classification.config:g' \
		"${D}etc/snort/snort.conf.distrib" \
		|| die "Failed to update snort.conf.distrib classification.config path"

	sed -i -e 's:^include reference.config:include /etc/snort/reference.config:g' \
		"${D}etc/snort/snort.conf.distrib" \
		|| die "Failed to update snort.conf.distrib /etc/snort/reference.config path"

	# Disable all rule files by default. 
	sed -i -e 's:^include $RULE_PATH:# include $RULE_PATH:g' \
		"${D}etc/snort/snort.conf.distrib" \
		|| die "Failed to disable rules in snort.conf.distrib"

	# Disable normalizer preprocessor config if normalizer USE flag not set.
	if ! use normalizer; then
		sed -i -e 's:^preprocessor normalize:#preprocessor normalize:g' \
			"${D}etc/snort/snort.conf.distrib" \
			|| die "Failed to disable normalizer config in snort.conf.distrib"
	fi

}

pkg_postinst() {

	einfo "There have been a number of improvements and new features"
	einfo "added to ${P}. Please review the RELEASE.NOTES and"
	einfo "ChangLog located in /usr/share/doc/${PF}."
	einfo
	elog "The Sourcefire Vulnerability Research Team (VRT) recommends that"
	elog "users migrate their snort.conf customizations to the latest config"
	elog "file released by the VRT. You can find the latest version of the"
	elog "Snort config file in /etc/snort/snort.conf.distrib."

	if use debug; then
		elog "You have the 'debug' USE flag enabled. If this has been done to"
		elog "troubleshoot an issue by producing a core dump or a back trace,"
		elog "then you need to also ensure the FEATURES variable in make.conf"
		elog "contains the 'nostrip' option."
	fi
}