# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-analyzer/snort/snort-2.9.0.4-r1.ebuild,v 1.1 2011/03/01 07:52:53 kumba Exp $

EAPI="2"
inherit eutils autotools multilib

DESCRIPTION="The de facto standard for intrusion detection/prevention"
HOMEPAGE="http://www.snort.org/"
SRC_URI="http://www.snort.org/downloads/1107 -> ${P}.tar.gz"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="static +dynamicplugin +zlib +gre +mpls +targetbased +decoder-preprocessor-rules
+ppm +perfprofiling linux-smp-stats inline-init-failopen +threads debug +active-response 
+normalizer reload-error-restart +react +flexresp3 paf aruba mysql odbc postgres selinux"

DEPEND=">=net-libs/libpcap-1.0.0
	>=net-libs/daq-0.5
	>=dev-libs/libpcre-6.0
	dev-libs/libdnet
	dev-util/pkgconfig
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
	sed -i -e 's|${exec_prefix}/lib|${exec_prefix}/'$(get_libdir)'|g' \
		"${WORKDIR}/${P}/src/dynamic-plugins/sf_engine/Makefile.am" || die "sed for sf_engine failed"

	#Multilib fix for the curent set of dynamic-preprocessors
	for i in ftptelnet smtp ssh dns ssl dcerpc2 sdf imap pop rzb_saac sip; do
		sed -i -e 's|${exec_prefix}/lib|${exec_prefix}/'$(get_libdir)'|g' \
			"${WORKDIR}/${P}/src/dynamic-preprocessors/$i/Makefile.am" || die "sed for $i failed."
	done

	AT_M4DIR=m4 eautoreconf
}

src_configure() {

	local myconf

	if use amd64; then
		myconf="--enable-large-pcap"
	else
		myconf="--disable-large-pcap"
	fi

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
		--without-oracle \
		${myconf}
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

	touch "${D}"/usr/share/snort/default/rules/local.rules

	insinto /usr/share/snort/default/preproc_rules
	doins preproc_rules/decoder.rules \
		preproc_rules/preprocessor.rules \
		preproc_rules/sensitive-data.rules || die "Failed to install preproc rule files"

	chown -R snort:snort \
		"${D}"/var/log/snort \
		"${D}"/var/run/snort \
		"${D}"/etc/snort \
		"${D}"/usr/share/snort || die "Failed to set ownership of dirs"

	newinitd "${FILESDIR}/snort.0.rc1" snort.0 || die "Failed to install snort init script"
	newconfd "${FILESDIR}/snort.confd.1" snort || die "Failed to install snort confd file"

	# Sourcefire uses Makefiles to install docs causing Bug #297190.
	# This removes the unwanted doc directory and rogue Makefiles.
	rm -rf "${D}"usr/share/doc/snort || die "Failed to remove SF doc directories"
	rm "${D}"usr/share/doc/"${PF}"/Makefile* || die "Failed to remove doc make files"

}

pkg_postinst() {
	einfo
	einfo "There have been a number of improvements and new features"
	einfo "added to ${P}. Please review the RELEASE.NOTES and"
	einfo "ChangLog located in /usr/share/doc/${PF}."
	einfo
	einfo "With the release of snort-2.9.1 the snort ebuild has under"
	einfo "gone a major rework. The Snort ebuild now supports running"
	einfo "multipule instances of Snort on a single sensor and pinning"
	einfo "individual Snort instances to a specific CPU. In addition,"
	einfo "a post install configuration process has been created to help"
	einfo "with creating and updating individual instances of Snort."
	elog
	elog "Snort-2.9.1 or newer users:"
	elog "Please run 'emerge --config snort' to update the core"
	elog "configuration files for your snort instances."
	elog
	elog "Upgrading to snort-2.9.1 from previous versions:"
	elog "If you are updating Snort from a version older than snort-2.9.1"
	elog "you will need to run 'etc-update' and replace /etc/conf.d/snort"
	elog "with the one provided by this ebuild. You will also need to"
	elog "migrate your current Snort configuration to the new instance"
	elog "based architecture."
	elog
	elog "Please run 'emerge --config snort' and follow the instructions"
	elog "to migrate your exsisting Snort install to the new configuration"
	elog "arachitecture."
	elog

	if use debug; then
		ewarn "You have selected the 'debug' USE flag. If you have done this"
		ewarn "to provide Sourcefire with a coredump or backtrace information"
		ewarn "to help troubleshoot a problem then you will also need to add"
		ewarn "the 'nostrip' option to FEATURES in make.conf and re-run"
		ewarn "'emerge snort'."
	fi
}

pkg_config() {

	clear
	echo "This configuration process is designed to:"
	echo
	echo "Help new users install their first instance of Snort"
	echo "and prform basic cleanup and configuration of the"
	echo "snort.conf file."
	echo
	echo "Help current users install additional instance of Snort"
	echo "and update critical files for existing snort-2.9.1 or newer instances."
	echo
	echo "Migration to snort-2.9.1:"
	echo
	echo "To migrate an existing snort install that is older than"
	echo "snort-2.9.1 to the new layout follow these steps:"
	echo
	echo "These steps are _required_ for installs of snort older than snort-2.9.1"
	echo
	echo "Setp 1. Choose 1 and following the directions to create"
	echo "        a new snort instance."
	echo
	echo "Step 2. Migrate your custom Snort settings to the"
	echo "        new snort.conf for the instance you just created."
	echo
	echo "Step 3. Copy your text and SO rules from /etc/snort/rules"
	echo "        and /etc/snort/so_rules to the new instance."
	echo
	echo "Step 4. (optional) If you are using a tool such as pulledpork"
	echo "        to manage your rules, you should update the config"
	echo "        file to point to the rule location for the instance"
	echo "        you created in Step 1."
	echo
	echo "Do you want to create a new instance of Snort or upgrade an existing instance?"

	select c_u in "Create" "Upgrade" "Exit"; do
		case ${c_u} in
			Create )

			echo
			echo "Please enter a name for this instance."
			echo "Format: The name must be alpha-numeric and no more than 8 characters in length."
			read -p "Name: " c_name
			echo
			read -p "Will this be a passive or inline instance, all lower case (passive/inline)" c_listen
			echo
			echo "Which interface(s) will Snort be listening on?"
			echo "For a passive deployment, enter a single NIC (ex. eth1)"
			echo "For an inline deployment, enter two NICs seperated by a colon (ex. eth1:eth2)"
			read -p "Enter interface(s): " c_iface
			echo
			echo "What Data Acquisition (DAQ) module do you want to use?"
			echo "afpacket - (New) Supports passive and inline modes. (recommended)"
			echo "pcap     - (Old) method. Supports passive mode only"
			echo "nfq      - (New) Supports inline mode. Requires iptables integration."
			echo "ipq      - (Old) Supports inline mode. Requires iptables integration."
			read -p "Enter DAQ Module, all lower case (afpacket/pcap/nfq/ipq):" c_daq

			echo "Creating a ${c_listen} instance called ${c_name} listening on ${c_iface}..."

			cp -R ${ROOT}usr/share/snort/default ${ROOT}etc/snort/${c_name}
			chown -R snort:snort ${ROOT}etc/snort/${c_name}
			mkdir ${ROOT}var/log/snort/${c_name}
			chown -R snort:snort ${ROOT}var/log/snort/${c_name}

			# Set the correct rule location in the config
			sed -i -e 's|RULE_PATH ../rules|RULE_PATH /etc/snort/'${c_name}'/rules|g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf rule path"

			# Set the correct so_rule location in the config
			sed -i -e 's|SO_RULE_PATH ../so_rules|SO_RULE_PATH /etc/snort/'${c_name}'/so_rules|g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf so_rule path"

			# Set the correct preprocessor/decoder rule location in the config
			sed -i -e 's|PREPROC_RULE_PATH ../preproc_rules|PREPROC_RULE_PATH /etc/snort/'${c_name}'/preproc_rules|g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf preproc rule path"

			# Set the configured DAQ
			sed -i -e 's|^# config daq: <type>|config daq: '${c_daq}'|g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf config daq"

			# Set the location of the DAQ modules
			sed -i -e 's|^# config daq_dir: <dir>|config daq_dir: /usr/'$(get_libdir)'/daq|g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf config daq_dir"

			# Set the DAQ mode
			sed -i -e 's|^# config daq_mode: <mode>|config daq_mode: '${c_listen}'|g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf config daq_mode"

			# Set snort to run as snort:snort
			sed -i -e 's|^# config set_gid:|config set_gid: snort|g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf config set_gid"
			sed -i -e 's|^# config set_uid:|config set_uid: snort|g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf config set_uid"

			# Set the default log dir
			sed -i -e 's|^# config logdir:|config logdir: /var/log/snort/'${c_name}'|g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf config logdir"

			# Set the correct lib path for dynamicpreprocessor, dynamicengine, and dynamicdetection
			sed -i -e 's|/usr/local/lib/snort_dynamicpreprocessor/|/usr/'$(get_libdir)'/snort_dynamicpreprocessor|g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf dynamicpreprocessor"
			sed -i -e 's|/usr/local/lib/snort_dynamicengine|/usr/'$(get_libdir)'/snort_dynamicengine|g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf dynamicengine"
			sed -i -e 's|/usr/local/lib/snort_dynamicrules|/usr/'$(get_libdir)'/snort_dynamicrules|g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf dynamicrules"

			# Normalization setup. Requires inline.
			if [ ${c_listen} != inline || ! use normalizer ]; then
			sed -i -e 's|^preprocessor normalize_|# preprocessor normalize_|g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to update snort.conf normalization"
			fi

			# Disable the text based rules. They are not shipped with the tarball.
			sed -i -e 's|^include $RULE_PATH/|# include $RULE_PATH/|g' \
				"${ROOT}etc/snort/${c_name}/snort.conf" || die "Failed to disable text rules"

			clear
			echo
			echo "Finished!"
			echo
			echo "A ${c_listen} instance of Snort, listening on ${c_iface}, using the ${c_daq} DAQ module,"
			echo "called ${c_name} has been created in:"
			echo
			echo "/etc/snort/${c_name}"
			echo
			echo "See /usr/share/doc/${PF} for information on configuring snort."
			echo
			echo "Please add the following line to /etc/conf.d/snort:"
			echo
			echo "config_snort<instance #>=( \""${c_name}"\" \"snort.conf\" \""${c_iface}"\" \"none\" )"
			echo
			echo "and change '<instance #>' to correspond to the snort init.d script you will use to"
			echo "start this instance of snort. (see the comments in /etc/conf.d/snort for more details)"
			echo
			return
			;;

			Upgrade )

			echo "Warning:"
			echo
			echo "This process is for updating exsiting snort-2.9.1 or newer instances."
			echo "If you are attempting to migrate an older version of snort to >=snort-2.9.1"
			echo "you should press Ctrl+C now and re-run 'emerge --config snort'"
			echo "and follow the three step migration process listed on the first screen."
			echo
			echo "Press ENTER to continue or press Ctrl+C to exit."
			read
			clear
			echo "This process will update the following files for an exsisting Snort instance:"
			echo
			echo "classification.config"
			echo "gen-msg.map"
			echo "reference.config"
			echo "unicode.map"
			echo
			echo "The following snort instances are currently installed:"
			echo
			read -p "Please enter the instance name you wish to update (case sensitive): " u_name

			if [ -e ${ROOT}etc/snort/"${u_name}" ]; then

				echo "Upgrading instance ${u_name}..."

				cp ${ROOT}usr/share/snort/default/classification.config ${ROOT}etc/snort/${u_name}
				cp ${ROOT}usr/share/snort/default/gen-msg.map ${ROOT}etc/snort/${u_name}
				cp ${ROOT}usr/share/snort/default/reference.config ${ROOT}etc/snort/${u_name}
				cp ${ROOT}usr/share/snort/default/unicode.map ${ROOT}etc/snort/${u_name}
				chown -R snort:snort ${ROOT}etc/snort/${u_name}

				clear
				echo "Finished!"
				echo
				echo "The Sourcefire Vulnerability Research Team (VRT) recommends that users"
				echo "migrate their snort.conf customizations to the latest config file"
				echo "released by the VRT."
				echo
				echo "If you chose to continue, your current snort.conf for the snort instance ${u_name}"
				echo "will be backed up to snort.conf.<unix time stamp> and a new snort.conf, with the"
				echo "required Gentoo changes, will be added to /etc/snort/${u_name}."
				echo
				echo "This process will migrate many (but not all) of your custom settings in your"
				echo "current config file to the new config file."
				echo
				echo "Would you like to continue with the snort.conf update?"

				select yn in "Continue" "Exit"; do
		        	case ${yn} in
						Continue )

							old_conf="${ROOT}etc/snort/${u_name}/snort.conf.`date +%s`"

							if [ -e ${ROOT}etc/snort/${u_name}/snort.conf ]; then

								mv ${ROOT}etc/snort/${u_name}/snort.conf ${old_conf}
								if [ ! -e ${old_conf} ]; then
									echo "Aborting: Backup of original config file failed."
									echo "          This should not happen. Please file a bug"
									echo "          at http://bugs.gentoo.org."
									exit
								fi
								cp ${ROOT}usr/share/snort/default/snort.conf /etc/snort/${u_name}
								chown snort:snort ${ROOT}etc/snort/${u_name}/snort.conf

			# Standard Changes
								# Set the correct rule location in the config
								sed -i -e 's|RULE_PATH ../rules|RULE_PATH /etc/snort/'${u_name}'/rules|g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf rule path"

								# Set the correct so_rule location in the config
								sed -i -e 's|SO_RULE_PATH ../so_rules|SO_RULE_PATH /etc/snort/'${u_name}'/so_rules|g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf so_rule path"

								# Set the correct preprocessor/decoder rule location in the config
								sed -i -e 's|PREPROC_RULE_PATH ../preproc_rules|PREPROC_RULE_PATH /etc/snort/'${u_name}'/preproc_rules|g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf preproc rule path"

								# Set the location of the DAQ modules
								sed -i -e 's|^# config daq_dir: <dir>|config daq_dir: /usr/'$(get_libdir)'/daq|g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf config daq_dir"

								# Set the correct lib path for dynamicpreprocessor, dynamicengine, and dynamicdetection
								sed -i -e 's|/usr/local/lib/snort_dynamicpreprocessor/|/usr/'$(get_libdir)'/snort_dynamicpreprocessor|g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf dynamicpreprocessor"
								sed -i -e 's|/usr/local/lib/snort_dynamicengine|/usr/'$(get_libdir)'/snort_dynamicengine|g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf dynamicengine"
								sed -i -e 's|/usr/local/lib/snort_dynamicrules|/usr/'$(get_libdir)'/snort_dynamicrules|g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf dynamicrules"

								# Set the default log dir
								sed -i -e 's|^# config logdir:|config logdir: /var/log/snort/'${u_name}'|g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to update snort.conf config logdir"

								# Disable the text based rules. They are not shipped with the tarball.
								sed -i -e 's|^include $RULE_PATH/|# include $RULE_PATH/|g' \
									"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to disable text rules"

			# Migrated Changes
								# If defined, migrate the configured DAQ
								if grep -q "^ *config daq:" ${old_conf}; then
									current_daq="`grep "^ *config daq:" ${old_conf}`"
									sed -i -e 's|^# config daq:.*$|'${current_daq}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config daq:"
								fi

								# If defined, migrate the DAQ mode
								if grep -q "^ *config daq_mode:" ${old_conf}; then
									curent_daq_mode="`grep "^ *config daq_mode:" ${old_conf}`"
									sed -i -e 's|^# config daq_mode:.*$|'${curent_daq_mode}'|g' \
										 "${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config daq_mode:"
								fi

								# If defined, migrate the DAQ mode
								if grep -q "^ *config daq_var:" ${old_conf}; then
									curent_daq_var="`grep "^ *config daq_var:" ${old_conf}`"
									sed -i -e 's|^# config daq_var:.*$|'${curent_daq_var}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config daq_var:"
								fi

								# If defined, migrate the configured gid/uid
								if grep -q "^ *config set_gid:" ${old_conf}; then
									current_gid="`grep "^ *config set_gid:" ${old_conf}`"
									sed -i -e 's|^# config set_gid:.*$|'${current_gid}'|g' \
										 "${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config set_gid:"
								fi
								if grep -q "^ *config set_uid:" ${old_conf}; then
									current_uid="`grep "^ *config set_uid:" ${old_conf}`"
									sed -i -e 's|^# config set_uid:.*$|'${current_uid}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config set_uid:"
								fi

								# If defined, migrate the configured snaplen
								if grep -q "^ *config snaplen:" ${old_conf}; then
									current_snaplen="`grep "^ *config snaplen:" ${old_conf}`"
									sed -i -e 's|^# config snaplen:.*$|'${current_snaplen}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config snaplen:"
								fi

								# If defined, migrate the configured pcre options
								if grep -q "^ *config pcre_match_limit:" ${old_conf}; then
									current_pcreml="`grep "^ *config pcre_match_limit:" ${old_conf}`"
									sed -i -e 's|^# config pcre_match_limit:.*$|'${current_pcreml}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config pcre_match_limit:"
								fi
								if grep -q "^ *config pcre_match_limit_recursion:" ${old_conf}; then
									current_pcremlr="`grep "^ *config pcre_match_limit_recursion:" ${old_conf}`"
									sed -i -e 's|^# config pcre_match_limit_recursion:.*$|'${current_pcremlr}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config pcre_match_limit_recursion:"
								fi

								# If defined, migrate the configured checksum_mode
								if grep -q "^ *config checksum_mode:" ${old_conf}; then
									current_checksum="`grep "^ *config checksum_mode:" ${old_conf}`"
									sed -i -e 's|^config checksum_mode:.*$|'${current_checksum}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config checksum_mode:"
								fi

								# If defined, migrate the configured response
								if grep -q "^ *config response:" ${old_conf}; then
									current_response="`grep "^ *config response:" ${old_conf}`"
									sed -i -e 's|^# config response:.*$|'${current_response}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config response:"
								fi

								# If defined, migrate the configured BPF
								if grep -q "^ *config bpf_file:" ${old_conf}; then
									current_bpf="`grep "^ *config bpf_file:" ${old_conf}`"
									sed -i -e 's|^# config bpf_file:.*$|'${current_bpf}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config bpf_file:"
								fi

								# If defined, migrate the configured detection
								if grep -q "^ *config detection:" ${old_conf}; then
									current_detection="`grep "^ *config detection:" ${old_conf}`"
									sed -i -e 's|^config detection:.*$|'${current_detection}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config detection:"
								fi

								# If defined, migrate the configured event_queue
								if grep -q "^ *config event_queue:" ${old_conf}; then
									current_event="`grep "^ *config event_queue:" ${old_conf}`"
									sed -i -e 's|^config event_queue:.*$|'${current_event}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config event_queue:"
								fi

								# If defined, migrate the configured normalize settings
								if grep -q "^ *config normalize_ip4" ${old_conf}; then
									current_nip4="`grep "^ *config normalize_ip4" ${old_conf}`"
									sed -i -e 's|^config normalize_ip4.*$|'${current_nip4}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config normalize_ip4"
								fi
								if grep -q "^ *config normalize_tcp" ${old_conf}; then
									current_ntcp="`grep "^ *config normalize_tcp" ${old_conf}`"
									sed -i -e 's|^config normalize_tcp.*$|'${current_ntcp}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config normalize_tcp"
								fi
								if grep -q "^ *config normalize_icmp4" ${old_conf}; then
									current_nicmp4="`grep "^ *config normalize_icmp4" ${old_conf}`"
									sed -i -e 's|^config normalize_icmp4.*$|'${current_nicmp4}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config normalize_icmp4"
								fi
								if grep -q "^ *config normalize_ip6" ${old_conf}; then
									current_nip6="`grep "^ *config normalize_ip6" ${old_conf}`"
									sed -i -e 's|^config normalize_ip6.*$|'${current_nip6}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config normalize_ip6"
								fi
								if grep -q "^ *config normalize_icmp6" ${old_conf}; then
									current_nicmp6="`grep "^ *config normalize_icmp6" ${old_conf}`"
									sed -i -e 's|^config normalize_icmp6.*$|'${current_nicmp4}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config normalize_icmp6"
								fi

								# Migrate some of the simple ipvar/portvar settings
								if grep -q "^ *ipvar HOME_NET" ${old_conf}; then
									current_home="`grep "^ *ipvar HOME_NET" ${old_conf}`"
									sed -i -e 's|^ipvar HOME_NET.*$|'${current_home}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config HOME_NET"
								fi
								if grep -q "^ *ipvar EXTERNAL_NET" ${old_conf}; then
									current_external="`grep "^ *ipvar EXTERNAL_NET" ${old_conf}`"
									sed -i -e 's|^ipvar EXTERNAL_NET.*$|'${current_external}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config EXTERNAL_NET"
								fi
								if grep -q "^ *ipvar DNS_SERVERS" ${old_conf}; then
									current_dns="`grep "^ *ipvar DNS_SERVERS" ${old_conf}`"
									sed -i -e 's|^ipvar DNS_SERVERS.*$|'${current_dns}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config DNS_SERVERS"
								fi
								if grep -q "^ *ipvar SMTP_SERVERS" ${old_conf}; then
									current_smtp="`grep "^ *ipvar SMTP_SERVERS" ${old_conf}`"
									sed -i -e 's|^ipvar SMTP_SERVERS.*$|'${current_smtp}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config SMTP_SERVERS"
								fi
								if grep -q "^ *ipvar HTTP_SERVERS" ${old_conf}; then
									current_http="`grep "^ *ipvar HTTP_SERVERS" ${old_conf}`"
									sed -i -e 's|^ipvar HTTP_SERVERS.*$|'${current_http}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config HTTP_SERVERS"
								fi
								if grep -q "^ *ipvar SQL_SERVERS" ${old_conf}; then
									current_sql="`grep "^ *ipvar SQL_SERVERS" ${old_conf}`"
									sed -i -e 's|^ipvar SQL_SERVERS.*$|'${current_sql}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config SQL_SERVERS"
								fi
								if grep -q "^ *ipvar TELNET_SERVERS" ${old_conf}; then
									current_telnet="`grep "^ *ipvar TELNET_SERVERS" ${old_conf}`"
									sed -i -e 's|^ipvar TELNET_SERVERS.*$|'${current_telnet}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config TELNET_SERVERS"
								fi
								if grep -q "^ *ipvar SSH_SERVERS" ${old_conf}; then
									current_ssh="`grep "^ *ipvar SSH_SERVERS" ${old_conf}`"
									sed -i -e 's|^ipvar SSH_SERVERS.*$|'${current_ssh}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config SSH_SERVERS"
								fi
								if grep -q "^ *ipvar FTP_SERVERS" ${old_conf}; then
									current_ftp="`grep "^ *ipvar FTP_SERVERS" ${old_conf}`"
									sed -i -e 's|^ipvar FTP_SERVERS.*$|'${current_ftp}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config FTP_SERVERS"
								fi
								if grep -q "^ *ipvar SIP_SERVERS" ${old_conf}; then
									current_sip="`grep "^ *ipvar SIP_SERVERS" ${old_conf}`"
									sed -i -e 's|^ipvar SIP_SERVERS.*$|'${current_sip}'|g' \
										"${ROOT}etc/snort/${u_name}/snort.conf" || die "Failed to migrate config SIP_SERVERS"
								fi

								clear
								echo "Finished!"
								echo
								echo "Your exsisting snort.conf has been backed up to ${old_conf} and a new one"
								echo "installed into /etc/snort/${u_name}."
								echo
								echo "The following options have been migrated for you:"
								echo
								echo "config options		ipvar options"
								echo "-----------------------------------"
								echo "daq					HOME_NET"
								echo "daq_mode				EXTERNAL_NET"
								echo "daq_var				DNS_SERVERS"
								echo "set_gid				SMTP_SERVERS"
								echo "set_uid				HTTP_SERVERS"
								echo "snaplen				SQL_SERVERS"
								echo "checksum_mode			TELNET_SERVERS"
								echo "response				SSH_SERVERS"
								echo "bpf_file				FTP_SERVERS"
								echo "detection				SIP_SERVERS"
								echo "event_queue"
								echo "normalize_ip4"
								echo "normalize_tcp"
								echo "normalize_icmp4"
								echo "normalize_ip6"
								echo "normalize_icmp6"
								echo "pcre_match_limit"
								echo "pcre_match_limit_recursion"
								echo
								echo
								echo "Please review the above options to ensure they were migrated properly"
								echo "and then manually migrate your other customizations to the new snort.conf."
								echo
								echo "Thank you, and happy snorting!"
								return

							else

								echo "The file /etc/snort/${u_name}/snort.conf does not exist."
								echo "Please check the instance name again and then run"
								echo "'emerge --config snort' again."
								return
							fi
							;;

						Exit )

							echo
							echo "Thank you, and happy snorting!"
							return
					esac
					done

			else

				echo "The directory /etc/snort/${u_name} does not exist. Please check the instance name"
				echo "again and then run 'emerge --config snort' again."
				return
			fi
			;;

			Exit )
				echo
				echo "Thank you, and happy snorting!"
				return

		esac
		done
}
