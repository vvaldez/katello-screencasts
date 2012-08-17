#!/bin/bash
#
# Helper script to setup katello and import RHEL + Custom content
#
# TODO
#  * add default environments for users
#  * Create a different user, and perform operations as that user
#  * Automatically create activation keys
#

MANIFEST=manifest-for-class.zip
KATELLO_ORG=Example
RHEL_VERSION=6.2	# Use '6Server' to obtain the latest
KS_VERSION=6.2		# Should match $RHEL_VERSION unless '6Server' is used
TEMPLATES_DIR=/var/www/html/pub/templates
KATELLO_USER=admin
KATELLO_PASS=password

# Determine whether running on an interactive tty (or a pipe)
isatty(){
    stdin="$(ls -l /proc/self/fd/0)"
    stdin="${stdin/*-> /}"

    if [[ "$stdin" =~ ^/dev/pts/[0-9] ]]; then
        return 0 # terminal
    else
        return 1 # pipe
    fi
}

# Helper to run a command and prompt upon failure
run_cmd() {
    cmd=$1 ; shift

    # Display the command if VERBOSE
    if [ $VERBOSE -eq 1 ]; then
        echo -en "\n$cmd "
        for arg in "$@" ; do
            if [[ $arg =~ [[:space:]] ]]; then
                echo -n "\"$arg\" "
            else
                echo -n "$arg "
            fi
        done
        echo # print newline
    fi

    time $cmd "$@"
    rc=$?
    if [ $rc -ne 0 ]; then
        echo -n "Error ($rc): command failed ($cmd $@).  Retry (r), Continue (c), stop (s)? "

        if isatty ; then
            read YESNO
            if [[ $YESNO == [cC] ]]; then
                return # just leave the function (allowing caller to proceed)
            elif [[ $YESNO == [rR] ]]; then
                run_cmd $cmd "$@"
            else
                exit $rc
            fi
        fi
    fi
}


k_cli () {
    run_cmd katello -u ${KATELLO_USER:-admin} -p ${KATELLO_PASS:-admin} "$@"
}

do_cli () {
    run_cmd "$@"
}

# Display usage message
usage() {
    echo "Usage: $(basename $0) <options>

Where <options> include:
   -v                   Enable verbose output
   -q                   Disable verbose output
   -h                   Show this help message
"
    exit 1
}

# Initialize variables
VERBOSE=1

# Process cmdline arguments
while getopts "qvh" options; do
  case $options in
    v ) VERBOSE=1 ;;
    q ) VERBOSE=0 ;;
    \?|h ) usage ;;
    * ) usage ;;
  esac
done
unset OPTIND

do_cli yum -y install http://fedorapeople.org/groups/katello/releases/yum/1.0/Fedora/16/x86_64/katello-repos-latest.rpm
do_cli yum -y install katello-all
do_cli iptables -I INPUT -p tcp --dport 443 -j ACCEPT
do_cli iptables -I INPUT -p tcp --dport 80 -j ACCEPT
do_cli iptables -I INPUT -p tcp --dport 5671 -j ACCEPT
do_cli /usr/libexec/iptables.service save
do_cli katello-configure \
	--user-name=${KATELLO_USER} \
	--user-pass=${KATELLO_PASS} \
	--org-name=${KATELLO_ORG}
do_cli sleep 7

# Create custom org and its cert (and remember it)
#k_cli org create --name ${KATELLO_ORG}
k_cli org uebercert --name ${KATELLO_ORG}
k_cli client remember --option org --value ${KATELLO_ORG}

# Create custom environments for staging content 
k_cli environment create --name dev --prior Library
k_cli environment create --name qa --prior dev
k_cli environment create --name production --prior qa

exit

# Create custom users

# The org-admin user are allowed to import and sync content for a specific organization
k_cli user create --username org-admin --password password --email root@localhost
k_cli user_role create --name org-admin-role
k_cli permission create --name org-all --user_role org-admin-role --org ${KATELLO_ORG} --scope all
k_cli user assign_role --username org-admin --role org-admin-role

# The following *Dev users are allowed to create and promote templates for a specific env
k_cli user_role create --name org-sysadmin-role
k_cli permission create --name org-keys --user_role org-sysadmin-role --org ${KATELLO_ORG} --scope activation_keys --verbs read_all,manage_all
k_cli permission create --name org-filt --user_role org-sysadmin-role --org ${KATELLO_ORG} --scope filters --verbs read
k_cli permission create --name org-org --user_role org-sysadmin-role --org ${KATELLO_ORG} --scope organizations --verbs delete_systems,update_systems,read,read_systems,register_systems
k_cli permission create --name org-providers --user_role org-sysadmin-role --org ${KATELLO_ORG} --scope providers --verbs read
k_cli permission create --name org-temps --user_role org-sysadmin-role --org ${KATELLO_ORG} --scope system_templates --verbs manage_all,read_all
k_cli permission create --name org-env --user_role org-sysadmin-role --org ${KATELLO_ORG} --scope environments --verbs read_changesets,read_contents 

k_cli user_role create --name org-dev-role
k_cli permission create --name org-dev-all --user_role org-dev-role --org ${KATELLO_ORG} --scope environments --verbs manage_changesets,update_systems,promote_changesets,read_changesets,read_contents,read_systems,register_systems,delete_systems --tag=Dev

k_cli user_role create --name org-QA-role
k_cli permission create --name org-QA-all --user_role org-QA-role --org ${KATELLO_ORG} --scope environments --verbs manage_changesets,update_systems,promote_changesets,read_changesets,read_contents,read_systems,register_systems,delete_systems --tag=QA

k_cli user_role create --name org-prod-role
k_cli permission create --name org-prod-all --user_role org-prod-role --org ${KATELLO_ORG} --scope environments --verbs manage_changesets,update_systems,promote_changesets,read_changesets,read_contents,read_systems,register_systems,delete_systems --tag=Production

k_cli user create --username sadev --password password --email root@localhost
k_cli user create --username saQA --password password --email root@localhost
k_cli user create --username saprod --password password --email root@localhost

k_cli user assign_role --username sadev --role org-sysadmin-role
k_cli user assign_role --username sadev --role org-dev-role
k_cli user assign_role --username saQA --role org-sysadmin-role
k_cli user assign_role --username saQA --role org-QA-role
k_cli user assign_role --username saprod --role org-sysadmin-role
k_cli user assign_role --username saprod --role org-prod-role

# need to set default env &&&&


# Import manifest
#k_cli provider update --name "Red Hat" --url http://cdn.rcm-qa.redhat.com
#k_cli provider import_manifest --name "Red Hat" --file $MANIFEST --force

# Enable specific repositories
#k_cli repo enable --product "Red Hat Enterprise Linux Server" --name "Red Hat Enterprise Linux 6 Server RPMs x86_64 ${RHEL_VERSION}"
#k_cli repo enable --product "Red Hat Enterprise Linux Server" --name "Red Hat CloudForms Tools for RHEL 6 RPMs x86_64 ${RHEL_VERSION}"

# Enable CloudForms Engine RHN channels
#k_cli repo enable --product "Red Hat CloudForms" --name "Red Hat CloudForms Cloud Engine RPMs x86_64 ${RHEL_VERSION}"

# Create customer provider content
k_cli provider create --name Classroom
k_cli product create --provider Classroom --name "Custom RHEL" --nodisc
k_cli repo create --product "Custom RHEL" --url "http://i.example.com/pub/rhel6/dvd/" --name rhel-6.2
k_cli product create --provider Classroom --name "Custom CloudForms" --nodisc
k_cli repo create --product "Custom CloudForms" --url "http://i.example.com/pub/cloudforms/rhel-x86_64-server-6-cf-tools-1/" --name cf-tools-1.0
k_cli repo create --product "Custom CloudForms" --url "http://i.example.com/pub/cloudforms/rhel-x86_64-server-6-cf-ce-1/" --name cf-ce-1.0
k_cli repo create --product "Custom CloudForms" --url "http://i.example.com/pub/cloudforms/epcf/" --name epcf-1.0

# Sync 
#k_cli provider synchronize --name "Red Hat"
k_cli provider synchronize --name Classroom

# Create and promote agents template (used for target_content.xml)
k_cli template create --name agents
k_cli template update --name agents --from_product "Custom RHEL" --add_repository "rhel-6.2"
k_cli template update --name agents --from_product "Custom CloudForms" --add_repository "cf-tools-1.0"
k_cli template update --name agents --add_distribution "ks-Red Hat Enterprise Linux-Server-${KS_VERSION}-x86_64"
for PKG in rhev-agent open-vm-tools katello-agent aeolus-audrey-agent 
do
   [ -z "$PKG" ] && continue
   if [[ $PKG == @* ]]; then
     k_cli template update --name agents --add_package_group ${PKG##*@}
   else
     k_cli template update --name agents --add_package ${PKG}
   fi
done

# Promote agents content
k_cli changeset create --name tools_content --environment Tools
k_cli changeset update --name tools_content --environment Tools --add_product "Custom RHEL"
k_cli changeset update --name tools_content --environment Tools --add_product "Custom CloudForms"
k_cli changeset update --name tools_content --environment Tools --add_template agents

# Create template for ConfigServer
k_cli template create --name ConfigServer
k_cli template update --name ConfigServer --from_product "Custom RHEL" --add_repository "rhel-6.2"
k_cli template update --name ConfigServer --from_product "Custom CloudForms" --add_repository "cf-tools-1.0"
k_cli template update --name ConfigServer --from_product "Custom CloudForms" --add_repository "cf-ce-1.0"
k_cli template update --name ConfigServer --add_distribution "ks-Red Hat Enterprise Linux-Server-${KS_VERSION}-x86_64"
k_cli template update --name ConfigServer --add_package aeolus-configserver
k_cli changeset create --name ConfigServer_content --environment Dev
k_cli changeset update --name ConfigServer_content --environment Dev --add_product "Custom CloudForms"
k_cli changeset update --name ConfigServer_content --environment Dev --add_product "Custom RHEL"
k_cli changeset update --name ConfigServer_content --environment Dev --add_template ConfigServer

# Create template for WebServer
k_cli template create --name WebServer
k_cli template update --name WebServer --from_product "Custom RHEL" --add_repository "rhel-6.2"
k_cli template update --name WebServer --from_product "Custom CloudForms" --add_repository "cf-tools-1.0"
k_cli template update --name WebServer --add_distribution "ks-Red Hat Enterprise Linux-Server-${KS_VERSION}-x86_64"
k_cli template update --name WebServer --add_package httpd
k_cli changeset create --name WebServer_content --environment Dev
k_cli changeset update --name WebServer_content --environment Dev --add_product "Custom CloudForms"
k_cli changeset update --name WebServer_content --environment Dev --add_product "Custom RHEL"
k_cli changeset update --name WebServer_content --environment Dev --add_template WebServer

# Create template for PostgreSQLServer
k_cli template create --name PostgreSQLServer
k_cli template update --name PostgreSQLServer --from_product "Custom RHEL" --add_repository "rhel-6.2"
k_cli template update --name PostgreSQLServer --from_product "Custom CloudForms" --add_repository "cf-tools-1.0"
k_cli template update --name PostgreSQLServer --add_distribution "ks-Red Hat Enterprise Linux-Server-${KS_VERSION}-x86_64"
k_cli template update --name PostgreSQLServer --add_package postgresql-server
k_cli changeset create --name PostgreSQLServer_content --environment Dev
k_cli changeset update --name PostgreSQLServer_content --environment Dev --add_product "Custom CloudForms"
k_cli changeset update --name PostgreSQLServer_content --environment Dev --add_product "Custom RHEL"
k_cli changeset update --name PostgreSQLServer_content --environment Dev --add_template PostgreSQLServer

k_cli changeset update --name tools_content --environment Tools --add_product "Custom CloudForms"
k_cli changeset promote --name tools_content --environment Tools
k_cli changeset promote --name ConfigServer_content --environment Dev
k_cli changeset promote --name WebServer_content --environment Dev
k_cli changeset promote --name PostgreSQLServer_content --environment Dev

# Export tempalte to /var/www/html/pub
[ ! -d ${TEMPLATES_DIR} ] && mkdir -p ${TEMPLATES_DIR}
restorecon -Rv ${TEMPLATES_DIR}
k_cli template export --name agents --format tdl --environment Tools --file "${TEMPLATES_DIR}/target_content-unformatted.xml" 
k_cli template export --name ConfigServer --environment Dev --format tdl --file "${TEMPLATES_DIR}/ConfigServer.xml"
k_cli template export --name WebServer --environment Dev --format tdl --file "${TEMPLATES_DIR}/WebServer.xml"
k_cli template export --name PostgreSQLServer --environment Dev --format tdl --file "${TEMPLATES_DIR}/PostgreSQLServer.xml"
echo "done."


