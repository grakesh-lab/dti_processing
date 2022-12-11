#!/usr/bin/env bash
#
# Collection of helper functions

readonly TITLE="UK Center for Addiction Neuromodulation DTI Pipeline"
readonly VERSION="0.5.0"
readonly AUTHORS="Pavan A. Anand"
readonly COPYRIGHT_YEARS="2022"

helpers::print_copyright() {
  echo "
${TITLE}
Version ${VERSION}
Copyright (C) ${COPYRIGHT_YEARS} ${AUTHORS}

These scripts are free software; see the \"LICENSE\" file distributed with the
scripts to learn about copying conditions. These scripts are provided with
absolutely no warranty: use them at your own discretion.

To view more information about the warranty (or lack thereof), execute:
  $ ${PROGRAM} -w
"  # $PROGRAM should be defined in the script that sources this one

exit 0
}

helpers::print_warranty() {
  echo "
This project is distributed in the hope that they will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
It should be distributed with the project under the name \"LICENSE\". If not,
please see <https://www.gnu.org/licenses/>.

To see a copyright notice, please execute:
  $ ${PROGRAM} -c
"  # $PROGRAM should be defined in the script that sources this one

exit 0
}
