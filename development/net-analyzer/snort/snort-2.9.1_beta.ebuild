# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-analyzer/snort/snort-2.9.0.4-r1.ebuild,v 1.1 2011/03/01 07:52:53 kumba Exp $

EAPI="2"
inherit eutils autotools multilib

DESCRIPTION="The de facto standard for intrusion detection/prevention"
HOMEPAGE="http://www.snort.org/"
SRC_URI="http://www.snort.org/downloads/1000 -> ${P}.tar.gz"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="static +dynamicplugin +zlib gre mpls targetbased +decoder-preprocessor-rules
ppm perfprofiling linux-smp-stats inline-init-failopen +threads debug active-response 
normalizer reload-error-restart react flexresp3 paf aruba mysql odbc postgres selinux"

DEPEND=">=net-libs/libpcap-1.0.0
	>=net-libs/daq-0.5
	>=dev-libs/libpcre-6.0
	dev-libs/libdnet
	postgres? ( dev-db/postgresql-base )
	mysql? ( virtual/mysql )
	odbc? ( dev-db/unixODBC )
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
		$(use_enable aruba) \
		$(use_with mysql) \
		$(use_with odbc) \
		$(use_with postgres postgresql) \
		--enable-ipv6 \
		--enable-reload \
		--disable-prelude \
		--disable-rzb-saac \
		--disable-build-dynamic-examples \
		--disable-profile \
		--disable-ppm-test \
		--disable-intel-soft-cpm \
		--disable-static-daq \
		--without-oracle

}

src_install() {

	emake DESTDIR="${D}" install || die "emake failed"

	dodir /var/log/snort \
		/var/run/snort \
		/etc/snort \
		/usr/share/snort/default/rules \
		/usr/share/snort/default/so_rules \
		/usr/share/snort/default/preproc_rules \
		/usr/$(get_libdir)/snort_dynamicrules \
			|| die "Failed to create core directories"

	dodoc RELEASE.NOTES ChangeLog \
		doc/* \
		tools/u2boat/README.u2boat \
		schemas/* || die "Failed to install snort docs"

	# snort.conf.orig is the original config file shipprd by Sourcefire
	newdoc etc/snort.conf snort.conf.orig

	# config.log and build.log are needed by Sourcefire
	# to troubleshoot build problems and bug reports so we are
	# perserving them incase the user needs upstream support.
	# 'die' was intentionally not added here. This should not
	# be a show stopper if it fails.
	if [ -f "${WORKDIR}/${PF}/config.log" ]; then
		dodoc "${WORKDIR}/${PF}/config.log"
	fi
	if [ -f "${T}/build.log" ]; then
		dodoc "${T}/build.log"
	fi

	insinto /usr/share/snort/default
	doins etc/snort.conf \
		etc/attribute_table.dtd \
		etc/classification.config \
		etc/gen-msg.map \
		etc/reference.config \
		etc/threshold.conf \
		etc/unicode.map || die "Failed to install docs in etc"

	touch /usr/share/snort/default/rules/local.rules

	insinto /usr/share/snort/default/preproc_rules
	doins preproc_rules/decoder.rules \
		preproc_rules/preprocessor.rules \
		preproc_rules/sensitive-data.rules || die "Failed to install preproc rule files"

	chown -R snort:snort \
		"${D}"/var/log/snort \
		"${D}"/var/run/snort \
		"${D}"/etc/snort \
		"${D}"/usr/share/snort || die "Failed to set ownership of dirs"

	newinitd "${FILESDIR}/snort.0.rc1" snort || die "Failed to install snort init script"
	newconfd "${FILESDIR}/snort.confd.1" snort || die "Failed to install snort confd file"

	# Sourcefire uses Makefiles to install docs causing Bug #297190.
	# This removes the unwanted doc directory and rogue Makefiles.
	rm -rf "${D}"usr/share/doc/snort || die "Failed to remove SF doc directories"
	rm "${D}"usr/share/doc/"${PF}"/Makefile* || die "Failed to remove doc make files"

}

pkg_postinst() {
	elog
	elog "Snort-2.9 introduces the DAQ, or Data Acquisition library, for"
	elog "packet I/O. The DAQ replaces direct calls to PCAP functions with"
	elog "an abstraction layer that	facilitates operation on a variety of"
	elog "hardware and software interfaces without requiring changes to Snort."
	elog
	elog "The only DAQ modules supported with this ebuild are AFpacket, PCAP,"
	elog "and Dump. IPQ nad NFQ will be supported in future versions of this"
	elog "package."
	elog
	elog "For passive (non-inline) Snort deployments you will want to use"
	elog "either PCAP or AFpacket. For inline deployments you will need"
	elog "to use AFpacket. The Dump DAQ is used for testing the various inline"
	elog "features available in ${P}."
	elog
	elog "The core DQA libraries are installed in /usr/$(get_libdir)/. The libraries"
	elog "for the individual DAQ modules (afpacket,pcap,dump) are installed in"
	elog "/usr/$(get_libdir)/daq. To use these you will need to add the following"
	elog "lines to your snort.conf:"
	elog
	elog "config daq: <DAQ module>"
	elog "config daq_mode: <mode>"
	elog "config daq_dir: /usr/$(get_libdir)/daq"
	elog
	elog "Please see the README file for DAQ for information about specific"
	elog "DAQ modules and README.daq from the Snort 2.9 documentation"
	elog "reguarding Snort and DAQ configuration information."
	elog
	elog "See /usr/share/doc/${PF} and /etc/snort/snort.conf.distrib for"
	elog "information on configuring snort."
	elog

	if [[ $(date +%Y%m%d) < 20110312 ]]; then

		ewarn
		ewarn "Please note, you can not use ${P} with the SO rules from"
		ewarn "previous versions of Snort!"
		ewarn
		ewarn "If you do not have a subscription to the VRT rule set and you"
		ewarn "wish to continue using the shared object (SO) rules, you will"
		ewarn "need to downgrade Snort. The SO rules will be made available"
		ewarn "to registered (non-subscription) users on March 12, 2011"
		ewarn "(30 days after being released to subscription users)."
		ewarn
		ewarn "Please see http://www.snort.org/snort-rules/#rules for more"
		ewarn "details."
		ewarn

	fi
}

pkg_config() {

	einfo "This configuration process is designed to:"
	einfo
	einfo "1. Help new users install their first instance of Snort"
	einfo "   and prform basic cleanup and configuration of the"
	einfo "   snort.conf file."
	einfo
	einfo "2. Help current users install additional instance of Snort"
	einfo "   and update critical files for existing Snort instances"
	einfo
	einfo "Press ENTER to continue or Ctrl+C to exit..."
	read
	echo
	echo
	echo "Do you want to create a new instance of Snort or upgrade"
	echo "an existing instance?"

	select c_u in "Create" "Upgrade"; do
		case ${c_u} in
			Create )

			echo
			read -p "Please enter a name for this instance (alpha/numeric and _ only): " c_name
			echo
			read -p "Which interface will Snort be listening on: " c_iface
			echo
			echo "Creating instance ${c_name} listening on ${c_iface}..."

			cp -R ${ROOT}/usr/share/snort/default ${ROOT}/etc/snort/${c_name}
			chown -R snort:snort ${ROOT}/etc/snort/${c_name}

			# Set the correct rule location in the config
			sed -i -e 's:RULE_PATH ../rules:RULE_PATH /etc/snort/'${c_name}'/rules:g' \
				"${ROOT}/etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf rule path"

			# Set the correct so_rule location in the config
			sed -i -e 's:SO_RULE_PATH ../rules:SO_RULE_PATH /etc/snort/'${c_name}'/so_rules:g' \
				"${ROOT}/etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf so_rule path"

			# Set the correct preprocessor/decoder rule location in the config
			sed -i -e 's:PREPROC_RULE_PATH ../preproc_rules:PREPROC_RULE_PATH /etc/snort/'${c_name}'/preproc_rules:g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf preproc rule path"

			# Set afpacket as the configured DAQ
			sed -i -e 's/^# config daq: <type>/config daq: afpacket/g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf config daq"

			# Set the location of the DAQ modules
			sed -i -e 's%^# config daq_dir: <dir>%config daq_dir: /usr/'$(get_libdir)'/daq%g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf config daq_dir"

			# Set the DAQ mode to passive
			sed -i -e 's%^# config daq_mode: <mode>%config daq_mode: passive%g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf config daq_mode"

			# Set snort to run as snort:snort
			sed -i -e 's%^# config set_gid:%config set_gid: snort%g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf config set_gid"
			sed -i -e 's%^# config set_uid:%config set_uid: snort%g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf config set_uid"

			# Set the default log dir
			sed -i -e 's%^# config logdir:%config logdir: /var/log/snort/'${c_name}'%g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf config logdir"

			# Set the correct lib path for dynamicpreprocessor, dynamicengine, and dynamicdetection
			sed -i -e 's:/usr/local/lib/snort_dynamicpreprocessor/:/usr/'$(get_libdir)'/snort_dynamicpreprocessor:g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf dynamicpreprocessor"
			sed -i -e 's:/usr/local/lib/snort_dynamicengine:/usr/'$(get_libdir)'/snort_dynamicengine:g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf dynamicengine"
			sed -i -e 's:/usr/local/lib/snort_dynamicrules:/usr/'$(get_libdir)'/snort_dynamicrules:g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf dynamicrules"

			# Disable normalization. Does nothing in passive mode
			sed -i -e 's:^preprocessor normalize_:# preprocessor normalize_:g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf normalization"

			echo
			echo "Finished!"
			echo
			echo "A passive instance of Snort, listening on ${c_iface} using the afpacket DAQ module"
			echo "and configured to drop permissions to snort:snort at start up, has been created in"
			echo
			echo "/etc/snort/${c_name}"
			echo
			echo "See /usr/share/doc/${PF} for information on configuring snort."
			echo
			echo "Please add the following line to /etc/conf.d/snort:"
			echo
			echo "config_snort<instance number>=( "${c_name}" "snort.conf" "${c_iface}" "none" )"
			echo
			echo "and change "<instance number>" to correspond to the snort init.d script you will use to"
			echo "start this instance of snort. (see the comments in /etc/conf.d/snort for more details)"
			echo
			exit
			;;

			Upgrade )

			echo "This process will update the following files for an exsisting Snort instance:"
			echo
			echo "classification.config"
			echo "gen-msg.map"
			echo "reference.config"
			echo "unicode.map"
			echo
			echo "Press ENTER to update these files or press Ctrl+C to exit."
			read
			echo
			echo
			read -p "Please the instance name you wish to update (case sensitive): " u_name

			if [ -e /etc/snort/"${u_name}" ]; then

				echo "Upgrading instance ${u_name}..."

				cp ${ROOT}/usr/share/snort/default/classification.config ${ROOT}/etc/snort/${u_name}
				cp ${ROOT}/usr/share/snort/default/gen-msg.map ${ROOT}/etc/snort/${u_name}
				cp ${ROOT}/usr/share/snort/default/reference.config ${ROOT}/etc/snort/${u_name}
				cp ${ROOT}/usr/share/snort/default/unicode.map ${ROOT}/etc/snort/${u_name}
				chown -R snort:snort ${ROOT}/etc/snort/${c_name}

				echo
				echo "Finished!"
				echo
				echo "The Sourcefire Vulnerability Research Team (VRT) recommends that users"
				echo "migrate their snort.conf customizations to the latest config file"
				echo "released by the VRT."
				echo
				echo "If you chose to continue, your current snort.conf for the snort instance ${u_name}"
				echo "will be backuped to snort.conf.<unix time stamp> and a new snort.conf, with the"
				echo "required Gentoo changes, will be added to /etc/snort/${u_name}."
				echo "You can then manually migrate your customizations to the new snort.conf."
				echo
				echo "Would you like to continue with the snort.conf update?"

				select yn in "Continue" "Exit"; do
		        	case ${yn} in
						Continue )

							echo "Backing up /etc/snort/${u_name}/snort.conf..."

							if [ -e /etc/snort/${u_name}/snort.conf ]; then

								mv /etc/snort/${u_name}/snort.conf /etc/snort/${u_name}/snort.conf.`date +%s`
								cp /usr/share/snort/default/snort.conf /etc/snort/${u_name}
								chown snort:snort ${ROOT}/etc/snort/${u_name}/snort.conf

								# Set the correct rule location in the config
								sed -i -e 's:RULE_PATH ../rules:RULE_PATH /etc/snort/'${u_name}'/rules:g' \
									"${ROOT}/etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf rule path"

								# Set the correct so_rule location in the config
								sed -i -e 's:SO_RULE_PATH ../rules:SO_RULE_PATH /etc/snort/'${u_name}'/so_rules:g' \
									"${ROOT}/etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf so_rule path"

								# Set the correct preprocessor/decoder rule location in the config
								sed -i -e 's:PREPROC_RULE_PATH ../preproc_rules:PREPROC_RULE_PATH /etc/snort/'${u_name}'/preproc_rules:g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf preproc rule path"

								# Set afpacket as the configured DAQ
								sed -i -e 's/^# config daq: <type>/config daq: afpacket/g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf config daq"

								# Set the location of the DAQ modules
								sed -i -e 's%^# config daq_dir: <dir>%config daq_dir: /usr/'$(get_libdir)'/daq%g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf config daq_dir"

								# Set the DAQ mode to passive
								sed -i -e 's%^# config daq_mode: <mode>%config daq_mode: passive%g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf config daq_mode"

								# Set snort to run as snort:snort
								sed -i -e 's%^# config set_gid:%config set_gid: snort%g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf config set_gid"
								sed -i -e 's%^# config set_uid:%config set_uid: snort%g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf config set_uid"

								# Set the default log dir
								sed -i -e 's%^# config logdir:%config logdir: /var/log/snort/'${u_name}'%g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf config logdir"

								# Set the correct lib path for dynamicpreprocessor, dynamicengine, and dynamicdetection
								sed -i -e 's:/usr/local/lib/snort_dynamicpreprocessor/:/usr/'$(get_libdir)'/snort_dynamicpreprocessor:g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf dynamicpreprocessor"
								sed -i -e 's:/usr/local/lib/snort_dynamicengine:/usr/'$(get_libdir)'/snort_dynamicengine:g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf dynamicengine"
								sed -i -e 's:/usr/local/lib/snort_dynamicrules:/usr/'$(get_libdir)'/snort_dynamicrules:g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf dynamicrules"

								# Disable normalization. Does nothing in passive mode
								sed -i -e 's:^preprocessor normalize_:# preprocessor normalize_:g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf normalization"

								echo
								echo "Finished!"
								echo
								echo "Your exsisting snort.conf has been backed up and a new one installed"
								echo "into /etc/snort/${u_name}."
								echo "Please manually migrate your customizations to the new snort.conf."
								echo
								echo "Thank you, and happy snorting!"
								exit

							else

								echo "The file /etc/snort/${u_name}/snort.conf does not exist."
								echo "Please check the instance name again and then run"
								echo "'emerge --config snort' again."
								exit
							fi
							;;

						Exit )

							echo
							echo "Thank you, and happy snorting!"
							exit
					esac
					done

			else

				echo "The directory /etc/snort/${u_name} does not exist. Please check the instance name"
				echo "again and then run 'emerge --config snort' again."
				exit
			fi

		esac
		done
}
