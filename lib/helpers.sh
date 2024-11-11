#!/usr/bin/env bash

# helpers.sh
# ----------
# Collection of helper functions

readonly TITLE="UK Center for Addiction Neuromodulation DTI Pipeline"
readonly VERSION="0.6.0"
readonly AUTHORS="Pavan A. Anand"
readonly COPYRIGHT_YEARS="2022-24"

helpers::print_version() {
  echo "${TITLE}, version ${VERSION}
Copyright (C) ${COPYRIGHT_YEARS} ${AUTHORS}"
}

helpers::print_example() {
  echo "Example usage:
    $ ${PROGRAM} ~/data/flanker/sub-01 flanker_analysis

  This  will run an analysis on all  sessions for subject  1  within the  \"flanker\"
  project.  <BIDS_ROOT>,  in  this  case,  is  \"~/data\",  as  it houses the project
  directory  (i.e.,  \"~/data/flanker\")  on  which the  analysis is to be performed.
  The component scripts  will search  for  (and create, if absent)  a \"derivatives\"
  &  an \"analysis\"  sub-directory under  <BIDS_ROOT>, inside which they will create
  a \"flanker_analysis\" sub-directory.

  Altogether, this example's outputs would be stored under:

    * \"~/data/derivatives/flanker_analysis\"
    * \"~/data/analysis/flanker_analysis\"
"
}

helpers::print_copyright() {
    echo "" # Adding padding for easier readability
    helpers::print_version
  echo -e "\nThese scripts are free software; see the \"LICENSE\" file distributed with the
scripts to learn about copying conditions. These scripts are provided with
absolutely no warranty: use them at your own discretion.

To view more information about the warranty (or lack thereof), execute:
  $ ${PROGRAM} -w\n"  # $PROGRAM should be defined in the calling script
}

helpers::print_warranty() {
  echo -e "\nThis project is distributed in the hope that they will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
It should be distributed with the project under the name \"LICENSE\". If not,
please see <https://www.gnu.org/licenses/>.

To see a copyright notice, please execute:
  $ ${PROGRAM} -c\n"  # $PROGRAM should be defined in the calling script
}
