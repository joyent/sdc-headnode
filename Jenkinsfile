/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

/*
 * Copyright 2020 Joyent, Inc.
 */

@Library('jenkins-joylib@v1.0.6') _

pipeline {

    options {
        buildDiscarder(logRotator(numToKeepStr: '30'))
        timestamps()
    }
    agent none

    // Build once per day, and start a few hours before
    // nightly reflashes tend to kick off, at 'H 4 * * *',
    // so we get reasonably up to date headnode images to
    // test with.
    triggers {
        cron('H 2 * * *')
    }

    parameters {
        text(
            name: 'CONFIGURE_BRANCHES',
            defaultValue: '',
            description:
                '<p>\n' +
                'Rather than writing JSON for the BUILD_SPEC_LOCAL\n' +
                'parameter, this allows you to specify the branches for the\n' +
                'various components you wish to to use in the headnode\n' +
                ' image.</p>' +
                '<p>See documentation from the\n' +
                '<a href="https://github.com/joyent/sdc-headnode/blob/master/README.md#build-specification-buildspec-and-buildspeclocal">\n' +
                'sdc-headnode</a> repository. In particular, see <a href="https://github.com/joyent/sdc-headnode/blob/master/README.md#alternative-branch-selection">\n' +
                'how to override branches</a>.\n' +
                '</p>\n' +
                '\n' +
                '<p>\n' +
                'Example:\n' +
                '</p>\n' +
                '\n' +
                '<p>\n' +
                '<pre>\n' +
                'bits-branch: release-20150514\n' +
                'cnapi: master\n' +
                'platform: master\n' +
                '</pre>\n' +
                '</p>'

        )
        text(
            name: 'BUILD_SPEC_LOCAL',
            defaultValue: '',
            description:
                'For power users, supply the full contents of a\n' +
                'build.spec.local file.\n' +
                'This is merged into the configuration before any\n' +
                'build.spec.branches file (hich is generated from\n' +
                'configure-branches)'
        )
        booleanParam(
            name: 'INCLUDE_DEBUG_STAGE',
            defaultValue: false,
            description: 'This parameter declares whether to build ' +
                'debug bits as well as the default non-debug bits'
        )
    }
    stages {
        stage('check') {
            agent {
                node {
                    label '!virt:kvm && fs:pcfs && fs:ufs && jenkins_agent:3 && pkgsrc_arch:multiarch'
                    customWorkspace "workspace/headnode-${BRANCH_NAME}-check"
                }
            }
            tools {
                nodejs 'sdcnode-v6-zone'
            }
            steps{
                sh('''
set -o errexit
set -o pipefail
make check
                ''')
            }
            post {
                // We don't mattermost-notify here, as that doesn't add much
                // value. The checks should always pass, and it's unlikely
                // that developers will care when they do. If they don't
                // pass, then the (likely) GitHub PR will be updated with a
                // failure status, and the developer can then investigate.

                // https://jenkins.io/doc/pipeline/steps/ws-cleanup/
                // We don't clean on build failure so that there's a chance to
                // investigate the breakage. Hopefully, a subsequent successful
                // build will then clean up the workspace, though that's not
                // guaranteed for abandoned branches.
                always {
                    cleanWs cleanWhenSuccess: true,
                        cleanWhenFailure: false,
                        cleanWhenAborted: true,
                        cleanWhenNotBuilt: true,
                        deleteDirs: true
                }
            }
        }
        stage('default') {
            agent {
                node {
                    label '!virt:kvm && fs:pcfs && fs:ufs && jenkins_agent:3 && pkgsrc_arch:multiarch'
                    customWorkspace "workspace/headnode-${BRANCH_NAME}-default"
                }
            }
            when {
                // We only want to trigger a full headnode build on either a
                // push to master, or an explicit build request from a user.
                // Otherwise, every push to a PR branch would cause a build,
                // which might be excessive. The exception is the 'check' stage
                // above, which is ~ a 2 minute build.
                beforeAgent true
                anyOf {
                    branch 'master'
                    triggeredBy cause: 'UserIdCause'
                }
            }
            tools {
                nodejs 'sdcnode-v6-zone'
            }
            steps {
                sh('git clean -fdx')
                sh('''
set -o errexit
set -o pipefail

# validate-buildenv checks for a delegated dataset,
# unnecessary for the headnode build
export ENGBLD_SKIP_VALIDATE_BUILDENV=true

if [[ -n "$CONFIGURE_BRANCHES" ]]; then
    echo "${CONFIGURE_BRANCHES}" > configure-branches
fi

if [[ -n "$BUILD_SPEC_LOCAL" ]]; then
    echo "$BUILD_SPEC_LOCAL" > build.spec.local
    json < build.spec.local
fi

# Ensure the 'gz-tools' image gets published.
export ENGBLD_BITS_UPLOAD_IMGAPI=true

# note we intentionally use bits-upload-latest
# so that our Manta path gets the 'latest-timestamp' override
# from our 'publish' target
make print-STAMP all publish bits-upload-latest
                ''')
            }
            post {
                always {
                    cleanWs cleanWhenSuccess: true,
                        cleanWhenFailure: false,
                        cleanWhenAborted: true,
                        cleanWhenNotBuilt: true,
                        deleteDirs: true
                }
            }
        }
    stage('debug') {
            agent {
                node {
                    label '!virt:kvm && fs:pcfs && fs:ufs && jenkins_agent:3 && pkgsrc_arch:multiarch'
                    customWorkspace "workspace/headnode-${BRANCH_NAME}-debug"
                }
            }
            when {
                beforeAgent true
                environment name: 'INCLUDE_DEBUG_STAGE', value: 'true'
                anyOf {
                    branch 'master'
                    triggeredBy cause: 'UserIdCause'
                }
            }
            tools {
                nodejs 'sdcnode-v6-zone'
            }
            steps {
                sh('git clean -fdx')
                sh('''
set -o errexit
set -o pipefail

# validate-buildenv checks for a delegated dataset,
# unnecessary for the headnode build
export ENGBLD_SKIP_VALIDATE_BUILDENV=true
export HEADNODE_VARIANT=debug

env

if [[ -n "$CONFIGURE_BRANCHES" ]]; then
    echo "${CONFIGURE_BRANCHES}" > configure-branches
fi

if [[ -n "$BUILD_SPEC_LOCAL" ]]; then
    echo "$BUILD_SPEC_LOCAL" > build.spec.local
    json < build.spec.local
fi

# Ensure the 'gz-tools' image gets published.
export ENGBLD_BITS_UPLOAD_IMGAPI=true

# note we intentionally use bits-upload-latest
# so that our Manta path gets the 'latest-timestamp' override
# from our 'publish' target
make print-STAMP all publish bits-upload-latest
                ''')
            }
            post {
                always {
                    cleanWs cleanWhenSuccess: true,
                        cleanWhenFailure: false,
                        cleanWhenAborted: true,
                        cleanWhenNotBuilt: true,
                        deleteDirs: true
                }
            }
        }
    }
    post {
        always {
            joyMattermostNotification(channel: 'jenkins')
        }
    }
}
