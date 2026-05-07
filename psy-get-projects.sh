#!/usr/bin/env bash

# shellcheck disable=SC2030,SC2031
set -Eeuo pipefail

function psy_get_projects() {
	{ #helpers
		_help() {
			cat <<-EOF
				$(printf "\e[1m%s\e[0m" "Get-psy-projects")

				$(printf "\e[1;4m%s\e[0m" "Usage:")
				  get-psy-projects [--options]

				$(printf "\e[1;4m%s\e[0m" "Options:")
				  -h, --help               <boolean?>      Display this help information.
				  -a, --all                <boolean?>      Enable download All projects.
				  -f, --force              <boolean?>      Enable Force mode.
				  -G, --generate-dotenv    <boolean?>      Enable Generate-Dotenv file.
				  -g, --git                <boolean?>      Enable Git mode.
				  -i, --install            <boolean?>      Enable Install project in Path.
				  -l, --list               <boolean?>      Enable List projects.
				  -I, --interactive        <boolean?>      Enable Interactive mode.
				  -n, --no-interactive     <boolean?>      Disable Interactive mode.
				  -s, --ssh                <boolean?>      Enable SSH clone repository.
				  -d, --directory          <string?>       Set Directory path value.
				  -k, --ssh-key            <string?>       Set SSH-Key value.
				  -p, --project            <string>        Set Project value.
				  -r, --root-password      <string?>       Set Root-Password value.
				  -t, --token              <string>        Set Github Token value.

				$(printf "\e[1;4m%s\e[0m" "Examples:")
				  get-psy-projects -p "bash-library" -d "~/installations" -t "ghp_123..."

				  get-psy-projects \ 
				    --project "bash-library" \ 
				    --directory "~/installations" \ 
				    --token "ghp_123..."

				  get-psy-projects --all --git --ssh --install

				$(printf "\e[1;4m%s\e[0m" "Notes:")
				  - Default directory installation: "~/installations/psy-projects"

			EOF

			exit 0
		}

		config_parse_args() {
			: || ((${#})) || _help

			while getopts ":-:hafgGilInsd:k:p:r:t:" opt; do
				case "${opt}" in
				h) _help ;;
				a) all="1" ;;
				f) force="1" ;;
				g) git="1" ;;
				G) generate_dotenv="1" ;;
				i) install="1" ;;
				l) list="1" ;;
				I) interactive="1" ;;
				n) no_interactive="1" ;;
				s) ssh="1" ;;
				d) directory="${OPTARG}" ;;
				k) ssh_key="${OPTARG}" ;;
				p) project="${OPTARG}" ;;
				r) root_password="${OPTARG}" ;;
				t) token="${OPTARG}" ;;
				-)
					case "${OPTARG}" in
					help) _help ;;
					all) all="1" ;;
					force) force="1" ;;
					git) git="1" ;;
					generate-dotenv) generate_dotenv="1" ;;
					install) install="1" ;;
					list) list="1" ;;
					interactive) interactive="1" ;;
					no-interactive) no_interactive="1" ;;
					ssh) ssh="1" ;;
					directory) directory="${!OPTIND:?$'\n'"$(throw_error "Option \"--${OPTARG}\" requires an argument.")"}" && ((OPTIND++)) ;;
					ssh-key) ssh_key="${!OPTIND:?$'\n'"$(throw_error "Option \"--${OPTARG}\" requires an argument.")"}" && ((OPTIND++)) ;;
					project) project="${!OPTIND:?$'\n'"$(throw_error "Option \"--${OPTARG}\" requires an argument.")"}" && ((OPTIND++)) ;;
					root-password) root_password="${!OPTIND:?$'\n'"$(throw_error "Option \"--${OPTARG}\" requires an argument.")"}" && ((OPTIND++)) ;;
					token) token="${!OPTIND:?$'\n'"$(throw_error "Option \"--${OPTARG}\" requires an argument.")"}" && ((OPTIND++)) ;;
					*) throw_error "Unknown long option: \"--${OPTARG}\"" ;;
					esac
					;;
				:) throw_error "Option \"-${OPTARG:-}\" requires an argument." ;;
				?) throw_error "Invalid option \"-${OPTARG:-}\"" ;;
				*) throw_error "Unknown option \"-${OPTARG:-}\"" ;;
				esac
			done
			shift "$((OPTIND - 1))"

			((${#})) && : "${*}" &&
				throw_error "${_:+$'\n'}    Invalid arguments: ${_:+$'\n'}      \"${_// /\"$'\n      \"'}\"" || printf ""
		}

		throw_error() {
			printf "%s%s%s" \
				$'\e[7;5;48;5;226;38;5;124m'" ERROR "$'\e[0m' \
				$'\e[48;5;233;38;5;124m'" ✘ [${BASH_SOURCE[-1]##*/}] ➤ "$'\e[0m' \
				$'\e[48;5;233;38;5;196m'"\"${1:-}\""$'\e[K\e[0m\n\n'

			# printf "\e[7;5;48;5;234;38;5;226m %s \e[0m\n" "WARNING"
			# printf "\e[7;5;48;5;226;38;5;124m %s \e[0m\n" "ERROR"
			# printf "\e[7;5;48;5;15;38;5;2m %s \e[0m\n"    "INFO"
			# ⚠ ✔ ❗ ❓ ⚡ ✨

			exit "${2:-1}"
		}
	}

	{ #utilities
		pgp__psy_get_projects() {
			{ #helpers
				pgp__print_all_projects() {
					printf "\n\e[1;48;5;39;38;5;15m %s \e[K\e[0m\n\n" "     List all Psy-Projects:       "

					for pgp__select_repo in "${iarr_psy_projects[@]}"; do
						printf "\e[2;7;48;5;254;2;38;5;88m  %s  \e[0m  \e[1;48;5;233;38;5;226m  \"%s\"  \e[K\e[0m\n" \
							"Owner:" "${aarr_psy_projects_owner[${pgp__select_repo}]}" \
							"Repo: " "${pgp__select_repo}" \
							"Alias:" "${aarr_psy_projects_alias[${pgp__select_repo}]:-}"

						printf "\n"
					done

					exit 0
				}

				pgp__check_core_lib_exists_or_download() {
					[[ -f "${pgp__path_core_default_directory}/bash-core-library/bash-core-library.sh" ]] && return 0

					(
						all=0
						list=0
						install=0
						generate_dotenv=0
						no_interactive=1

						pgp__disable_print_info=1

						[[ -n "${token}" ]] && pgp__token="${token}" git=0 ssh=0

						pgp__download_project \
							--owner "psy-projects-bash" \
							--repo "bash-core-library" \
							--output "${pgp__path_core_default_directory}" ||
							throw_error "Failed to download \"bash-core-library\""
					)

					return 0
				}

				pgp__download_project() {
					{ #helpers
						_help() {
							cat <<-EOF
								$(printf "\e[1m%s\e[0m" "pgp__download_project")

								$(printf "\e[1;4m%s\e[0m" "Usage:")
								  pgp__download_project [--options]

								$(printf "\e[1;4m%s\e[0m" "Options:")
								  -h, --help      <boolean?>      Display this help information.
								  -o, --owner     <string>        Set Owner value.
								  -r, --repo      <string>        Set Repo value.
								  -O, --output    <string>        Set Output path directory value.

								$(printf "\e[1;4m%s\e[0m" "Examples:")
								  pgp__download_project -o "psy" -r "bash-project" -O "\${HOME}/installations"

								  pgp__download_project \ 
								    --owner "psy" \ 
								    --repo "bash-project" \ 
								    --output "\${HOME}/installations"

							EOF

							exit 0
						}

						config_parse_args() {
							((${#})) || _help

							while ((${#})); do
								arg="${1:-}" val="${2:-}" && shift

								case "${arg}" in
								-h | --help) _help ;;
								-o | --owner) dp__owner="${val:?$'\n'"$(throw_error "Option \"${arg}\" requires an argument.")"}" && shift ;;
								-r | --repo) dp__repo="${val:?$'\n'"$(throw_error "Option \"${arg}\" requires an argument.")"}" && shift ;;
								-O | --output) dp__path_output_directory="${val:?$'\n'"$(throw_error "Option \"${arg}\" requires an argument.")"}" && shift ;;
								*) throw_error "Unknown option \"${arg}\"" ;;
								esac
							done
						}
					}

					{ #utilities
						dp__download_project() {
							{ #helpers
								dp__print_info() {
									((pgp__disable_print_info)) && return 0

									if ((git)); then
										pgp__print_log_line -l "GET GIT" -r "${dp__repo//-/ }"
									else
										pgp__print_log_line -l "GET" -r "${dp__repo//-/ }"
									fi

									printf "           \e[2;96m%s \e[93m\"%s\"\e[0m\n" \
										"Owner:     " "${dp__owner}" \
										"Repo:      " "${dp__repo}" \
										"Directory: " "${dp__path_download_project_directory}"

									[[ -z "${pgp__token}" ]] && printf "\n\n" && return 0

									printf "           \e[2;96m%s \e[93m\"%s\"\e[0m\n" \
										"Token:     " "${pgp__token::8}****************"

									printf "\n\n"
								}

								dp__get_tarball() {
									{ #helpers
										dp__http_request() {
											((ssh || git)) && throw_error "options \"--ssh\" and \"--git\" are not allowed"

											dp__http_response_code="$(
												curl \
													--header "Accept: application/vnd.github+json" \
													--header "Authorization: Bearer ${pgp__token}" \
													--header "X-GitHub-Api-Version: 2022-11-28" \
													--location "${dp__url}" \
													--output "${dp__path_tmp_tar_file}" \
													--write-out "%{http_code}" \
													--silent
											)"
										}

										dp__extract_tarball() {
											tar \
												--extract \
												--gzip \
												--strip-components=1 \
												--directory "${dp__path_download_project_directory}" \
												--file "${dp__path_tmp_tar_file}" ||
												throw_error "Failed to extract tarball from \"${dp__path_tmp_tar_file}\" to \"${dp__path_output_directory}\""

											((pgp__disable_print_info)) || printf "\e[93m%s  \e[96m\"%s\"\n" \
												$'\n'"Info:" "Tarball downloaded and extracted successfully from Github" \
												"Path:" "${dp__path_download_project_directory}" \
												"Url: " "github.com/${dp__owner}/${dp__repo}"

											rm -fr "${dp__path_tmp_tar_directory}"

											((pgp__disable_print_info)) || printf "\e[0m\n\n"
										}
									}

									{ #utilities
										dp__run_get_tarball() {
											dp__http_request

											if ((dp__http_response_code == 200)); then
												dp__extract_tarball

												dp__list_content_download_project_directory
											else
												printf "\e[91m%s  \e[95m\"%s\"\n" \
													$'\n'"ERROR:" "Failed get Tarball from Github" \
													"Code: " "${dp__http_response_code}" \
													"Url:  " "${dp__url}"

												[[ -s "${dp__path_tmp_tar_file}" ]] && cat "${dp__path_tmp_tar_file}"

												rm -fr "${dp__path_tmp_tar_directory}"

												printf "\e[0m\n\n"

												return 1
											fi
										}
									}

									{ #variables
										declare -i dp__http_response_code="${dp__http_response_code:+0}"

										declare \
											dp__path_tmp_tar_directory="${dp__path_tmp_tar_directory:+}" \
											dp__path_tmp_tar_file="${dp__path_tmp_tar_file:+}"
									}

									{ #setting-variables
										dp__path_tmp_tar_directory="$(mktemp --directory -t "${dp__repo}.XXXXXX")"
										dp__path_tmp_tar_file="${dp__path_tmp_tar_directory}/${dp__repo}.tar.gz"

										{ #debug
											: || printf "\e[92m%s\n" \
												$'\n' \
												$'\e[2;92m[DEBUG]\e[0;92m '"${FUNCNAME[0]^}()" \
												$'' \
												"    dp__path_tmp_tar_directory:               \"${dp__path_tmp_tar_directory}\"" \
												"    dp__path_tmp_tar_file:                    \"${dp__path_tmp_tar_file}\"" \
												$'\e[0m'
										}
									}

									:

									dp__run_get_tarball
								}

								dp__get_repo() {
									printf "\e[2;96m"

									GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' \
										git clone \
										"${dp__url}" \
										"${dp__path_download_project_directory}" 2>&1

									dp__list_content_download_project_directory

									printf "\e[0m"
								}

								dp__check_download_project_directory() {
									if [[ -d "${dp__path_download_project_directory}" ]]; then
										pgp__print_confirm \
											--label "Directory already exists: "$'\e[1;91m'"\"${dp__path_download_project_directory}\"" \
											--question "Do you want to remove the directory and continue?" \
											--default-yes || throw_error "Directory already exists: \"${dp__path_download_project_directory}\""

										rm -fr "${dp__path_download_project_directory}"
										mkdir -p "${dp__path_download_project_directory}"
									else
										mkdir -p "${dp__path_download_project_directory}"
									fi
								}

								dp__list_content_download_project_directory() {
									[[ -f "${dp__path_download_project_directory}/${dp__repo}.sh" ]] &&
										chmod +x "${dp__path_download_project_directory}/${dp__repo}.sh"

									((pgp__disable_print_info)) && return 0

									du -hs "${dp__path_download_project_directory}" && printf "\e[0m\n"

									if type tree &>/dev/null; then
										tree -hI ".GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' " --du --dirsfirst "${dp__path_download_project_directory}"
									else
										ls -hasl --color "${dp__path_download_project_directory}"
									fi

									printf "\e[0m\n\n"
								}

								:

								set_dp__url() {
									if ((git)) && [[ -n "${pgp__token}" ]]; then
										printf -v "dp__url" "https://%s@%s/%s/%s.%s" \
											"${pgp__token}" \
											"github.com" \
											"${dp__owner}" \
											"${dp__repo}" \
											"git"
									elif ((ssh)); then
										printf -v "dp__url" "git@%s:%s/%s.git" \
											"github.com" \
											"${dp__owner}" \
											"${dp__repo}"
									else
										printf -v "dp__url" "https://%s/%s/%s/%s" \
											"api.github.com/repos" \
											"${dp__owner}" \
											"${dp__repo}" \
											"tarball"
									fi
								}
							}

							{ #utilities
								dp__run_download_project() {
									dp__print_info
									dp__check_download_project_directory

									if ((ssh || git)); then
										dp__get_repo
									else
										dp__get_tarball
									fi
								}
							}

							{ #variables
								declare \
									dp__url="${dp__url:+}" \
									dp__path_download_project_directory="${dp__path_download_project_directory:+}"
							}

							{ #setting-variables
								set_dp__url

								dp__path_download_project_directory="${dp__path_output_directory}/${dp__repo}"

								{ #debug
									: || printf "\e[92m%s\n" \
										$'\n' \
										$'\e[2;92m[DEBUG]\e[0;92m '"${FUNCNAME[0]^}()" \
										$'' \
										"    dp__url:                                  \"${dp__url}\"" \
										"    dp__path_download_project_directory:      \"${dp__path_download_project_directory}\"" \
										$'\e[0m'
								}
							}

							:

							dp__run_download_project
						}
					}

					{ #variables
						declare \
							dp__owner="${dp__owner:+}" \
							dp__repo="${dp__repo:+}" \
							dp__path_output_directory="${dp__path_output_directory:+}"
					}

					{ #setting-variables
						config_parse_args "${@}"

						[[ -n "${dp__owner}" ]] || throw_error "option \"--owner\" is required"
						[[ -n "${dp__repo}" ]] || throw_error "option \"--repo\" is required"
						[[ -n "${dp__path_output_directory}" ]] || throw_error "option \"--output\" is required"

						{ #debug
							: || printf "\e[92m%s\n" \
								$'\n' \
								$'\e[2;92m[DEBUG]\e[0;92m '"${FUNCNAME[0]^}()" \
								$'' \
								"    dp__owner:                     \"${dp__owner}\"" \
								"    dp__repo:                      \"${dp__repo}\"" \
								"    dp__path_output_directory:     \"${dp__path_output_directory}\"" \
								$'\e[0m'
						}
					}

					:

					dp__download_project
				}

				pgp__check_generate_dotenv_file() {
					{ #helpers
						pgp__generate_dotenv_file() {
							pushd "${pgp__project_main_script_directory}" >/dev/null || throw_error "Failed to change directory to \"${pgp__project_main_script_directory}\""

							if [[ -n "${token}" ]]; then
								PSY_GITHUB_TOKEN="${token}" \
									bash "${pgp__project_main_script_file}" --generate-dotenv
							elif [[ -n "${pgp__token}" ]]; then
								PSY_GITHUB_TOKEN="${pgp__token}" \
									bash "${pgp__project_main_script_file}" --generate-dotenv
							else
								bash "${pgp__project_main_script_file}" --generate-dotenv
							fi || throw_error "Failed to generate dotenv file"

							popd >/dev/null || throw_error "Failed to change directory to previous"
						}
					}

					{ #utilities
						pgp__run_check_generate_dotenv_file() {
							[[ -f "${pgp__project_main_script_file}" ]] || throw_error "File \"${pgp__project_main_script_file}\" not found."

							((generate_dotenv)) && pgp__generate_dotenv_file && return 0

							pgp__print_confirm \
								--question "Do you want to generate dotenv file?" \
								--default-yes || return 0

							pgp__generate_dotenv_file
						}
					}

					{ #variables
						declare \
							pgp__project_main_script_directory="${pgp__project_main_script_directory:+}" \
							pgp__project_main_script_file="${pgp__project_main_script_file:+}"
					}

					{ #setting-variables
						((no_interactive)) && ! ((generate_dotenv)) && return 0
						[[ -n "${pgp__select_repo}" ]] || throw_error "{pgp__select_repo} is required."

						pgp__project_main_script_directory="${pgp__path_psy_projects_directory}/${pgp__select_repo}"
						pgp__project_main_script_file="${pgp__project_main_script_directory}/${pgp__select_repo}.sh"
					}

					:

					pgp__run_check_generate_dotenv_file
				}

				pgp__check_install_project() {
					{ #helpers
						pgp__install_project() {
							[[ -n "${pgp__root_password}" ]] || install=1 set_pgp__root_password

							printf "%s\n" "${pgp__root_password}" |
								sudo -S \
									ln -sfv \
									"${pgp__project_main_script_file}" \
									"/usr/local/bin/${pgp__select_repo}"

							printf "\n\n"
						}
					}

					{ #utilities
						pgp__run_install_project() {
							[[ -f "${pgp__project_main_script_file}" ]] || throw_error "File \"${pgp__project_main_script_file}\" not found."

							[[ "${pgp__select_repo}" == "bash-core-library" ]] && return 0

							((install)) && pgp__install_project && return 0

							((no_interactive)) && return 0

							pgp__print_confirm \
								--default-yes \
								--question "Do you want to install \"${pgp__select_repo}\"?" || return 0

							pgp__install_project
						}
					}

					{ #variables
						declare \
							pgp__project_main_script_directory="${pgp__project_main_script_directory:+}" \
							pgp__project_main_script_file="${pgp__project_main_script_file:+}"
					}

					{ #setting-variables
						[[ -n "${pgp__select_repo}" ]] || throw_error "{pgp__select_repo} is required."

						pgp__project_main_script_directory="${pgp__path_psy_projects_directory}/${pgp__select_repo}"
						pgp__project_main_script_file="${pgp__project_main_script_directory}/${pgp__select_repo}.sh"
					}

					:

					pgp__run_install_project
				}

				:

				pgp__print_input() {
					{ #helpers
						_help() {
							cat <<-EOF
								$(printf "\e[1;93m%s\e[0m" "pgp__Print_input")

								$(printf "\e[1;4;93m%s\e[0m" "Usage:")
								  pgp__print_input [--options]

								$(printf "\e[1;4;93m%s\e[0m" "Options:")
								  -h, --help            <boolean?>      Display this help information.
								  -l, --label           <string?>       Set Label value.
								  -o, --var-output      <string?>       Set Output-Value name variable.
								  -p, --password        <boolean?>      Enable Password mode.
								  -P, --prompt          <string?>       Set Prompt value.
								  -T, --placeholder     <string?>       Set Placeholder value.

								$(printf "\e[1;4;93m%s\e[0m" "Examples:")
								  pgp__print_input -l "Login" -P "Username: " -T "Enter your username" -o "username_variable"

								  pgp__print_input \ 
								    --label "Login" \ 
								    --prompt "Username" \ 
								    --placeholder "Enter your username" \ 
								    --var-output "username_variable"
							EOF

							exit 0
						}

						config_parse_args() {
							((${#})) || _help

							while ((${#})); do
								arg="${1:-}" val="${2:-}" && shift

								case "${arg}" in
								-h | --help) _help ;;
								-p | --password) pi__mode_password="1" ;;
								-l | --label) pi__label="${val:?$'\n'"$(throw_error "Option \"${arg}\" requires an argument.")"}" && shift ;;
								-o | --var-output) pi__name_variable_output="${val:?$'\n'"$(throw_error "Option \"${arg}\" requires an argument.")"}" && shift ;;
								-P | --prompt) pi__prompt="${val:?$'\n'"$(throw_error "Option \"${arg}\" requires an argument.")"}" && shift ;;
								-T | --placeholder) pi__placeholder="${val:?$'\n'"$(throw_error "Option \"${arg}\" requires an argument.")"}" && shift ;;
								*) throw_error "Unknown option \"${arg}\"" ;;
								esac
							done
						}
					}

					{ #utilities
						pi__print_input() {
							{ #helpers
								pi__get_input_from_stdin() {
									declare k1 k2 k3

									while :; do
										IFS= read -rsn1 pi__character &>/dev/null

										read -rsn1 -t 0.0001 k1
										read -rsn1 -t 0.0001 k2
										read -rsn1 -t 0.0001 k3

										pi__character+="${k1}${k2}${k3}"

										[[ -z "${pi__character}" ]] &&
											printf "\e[2K\e[1A\e[2K\e[1A\e[2K\e[0G" &&
											break

										case "${pi__character}" in
										$'\x7f') # backspace
											((${#pi__input_line})) && {
												pi__input_line="${pi__input_line%?}"
												printf "\b \b"

												[[ -n "${pi__input_line}" ]] ||
													printf "%s" "${pi__format_placeholder}"
											}
											;;
										$'\x0a') : ;;             # enter/return
										$'\x1b') break ;;         # escape
										$'\e[F') : ;;             # end
										$'\e[H') : ;;             # home
										$'\x1b\x5b\x32\x7e') : ;; # insert
										$'\x1b\x5b\x41') : ;;     # up
										$'\x1b\x5b\x42') : ;;     # down
										$'\x1b\x5b\x43') : ;;     # right
										$'\x1b\x5b\x44') : ;;     # left
										$'\x1b\x5b\x35\x7e') : ;; # page up
										$'\x1b\x5b\x36\x7e') : ;; # page down
										*)
											[[ -n "${pi__input_line}" ]] ||
												printf "%s\e[%sD" \
													"${pi__filler_placeholder}" "${#pi__format_placeholder}"

											pi__input_line+="${pi__character}"

											if ((pi__mode_password)); then
												printf "*"
											else
												printf "%s" "${pi__character}"
											fi
											;;
										esac
									done
								}
							}

							{ #utilities
								pi__run_print_input() {
									((no_interactive)) && return 0

									[[ -n "${pi__label}" ]] && printf "%s\n" "${pi__format_label}"
									[[ -n "${pi__prompt}" ]] && printf "%s" "${pi__format_prompt}"
									[[ -n "${pi__placeholder}" ]] && printf "%s" "${pi__format_placeholder}"

									pi__get_input_from_stdin || :

									if [[ -n "${pi__name_variable_output}" ]]; then
										declare -n pi__output="${pi__name_variable_output}"
										[[ -n "${pi__input_line}" ]] && pi__output="${pi__input_line}"
									else
										[[ -n "${pi__input_line}" ]] && printf "%s\n\n" "${pi__input_line}"
									fi
								}
							}

							{ #variables
								declare \
									pi__format_label="${pi__format_label:+}" \
									pi__format_prompt="${pi__format_prompt:+}" \
									pi__format_placeholder="${pi__format_placeholder:+}"

								declare \
									pi__input_line="${pi__input_line:+}" \
									pi__character="${pi__character:+}" \
									pi__output="${pi__output:+}"
							}

							{ #setting-variables

								{ # pi__format_label
									printf -v "pi__format_label" "%s%s" \
										$'\e[7;5;48;5;15;38;5;2m'" INPUT "$'\e[0m' \
										$'\e[48;5;233;38;5;34m'" ⚡ ${pi__label^}"$'\e[K\e[0m'
								}

								{ # pi__format_prompt
									printf -v pi__format_prompt "%-22s" \
										$'\e[1;96m'"┊┊┊┊┊┊┊" \
										$'\n\e[1;96m'"░░░░░░░ ✎  " \
										$'\e[38;5;33m'"${pi__prompt^}: "$'\e[0m'
								}

								{ # pi__format_placeholder
									if [[ -n "${pi__name_variable_output}" ]]; then
										declare -n pi__output="${pi__name_variable_output}"

										[[ -n "${pi__output}" ]] && {
											pi__placeholder="${pi__output}"
										}
									fi

									printf -v pi__format_placeholder "\e[38;5;236m%s\e[0m\e[%sD" \
										"${pi__placeholder}" "${#pi__placeholder}"
								}

								{ # pi__filler_placeholder
									printf -v pi__filler_placeholder "%${#pi__format_placeholder}s" " "
								}
							}

							:

							pi__run_print_input
						}
					}

					{ #variables
						declare -i pi__mode_password="${pi__mode_password:+0}"

						declare \
							pi__name_variable_output="${pi__name_variable_output:+}" \
							pi__label="${pi__label:+}" \
							pi__prompt="${pi__prompt:+}" \
							pi__placeholder="${pi__placeholder:+}"
					}

					{ #setting-variables
						config_parse_args "${@}"

						{ # options
							[[ -n "${pi__placeholder}" ]] || pi__placeholder="Type text..."
						}
					}

					:

					pi__print_input
				}

				pgp__print_confirm() {
					{ #helpers
						_help() {
							cat <<-EOF
								$(printf "\e[1m%s\e[0m" "pgp__print_confirm")

								$(printf "\e[1;4m%s\e[0m" "Usage:")
								  pgp__print_confirm [--options]

								$(printf "\e[1;4m%s\e[0m" "Options:")
								  -h, --help           <boolean?>      Display this help information.
								  -l, --label          <string?>       Set Label value.
								  -q, --question       <string?>       Set Question value.
								  -Y, --default-yes    <boolean?>      Enable Yes Default value.
								  -N, --default-no     <boolean?>      Enable No Default value.
								  -D, --default-off    <boolean?>      Disable Default value.

								$(printf "\e[1;4m%s\e[0m" "Examples:")
								  pgp__print_confirm -l "Label" -q "do you want to continue?" -Y

								  pgp__print_confirm \ 
								    --label "Label" \ 
								    --question "do you want to continue?" \ 
								    --default-yes

							EOF

							exit 0
						}

						config_parse_args() {
							((${#})) || _help

							while ((${#})); do
								arg="${1:-}" val="${2:-}" && shift

								case "${arg}" in
								-h | --help) _help ;;
								-l | --label) pc__label="${val:?$'\n'"$(throw_error "Option \"${arg}\" requires an argument.")"}" && shift ;;
								-q | --question) pc__question="${val:?$'\n'"$(throw_error "Option \"${arg}\" requires an argument.")"}" && shift ;;
								-Y | --default-yes) pc__default_yes="1" ;;
								-N | --default-no) pc__default_no="1" ;;
								-D | --default-off) pc__default_off="1" ;;
								*) throw_error "Unknown option \"${arg}\"" ;;
								esac
							done
						}
					}

					{ #utilities
						pc__print_confirm() {
							{ #helpers
								pc__print_question_interactive() {
									((no_interactive)) && return 0

									declare k1 k2 k3

									printf "\e7" # Save the current cursor position

									while :; do
										if ((pc__suggestion)); then
											((pc__printed_suggestion)) || printf "%s\n" "${pc__suggestion_prompt}"

											pc__printed_suggestion=1
										else
											[[ -n "${pc__label}" ]] && printf "%s\n" "${pc__format_label}"

											printf "%s\n" "${pc__format_prompt}"
										fi

										IFS= read -rsn1 pc__reply &>/dev/null

										read -rsn1 -t 0.0001 k1
										read -rsn1 -t 0.0001 k2
										read -rsn1 -t 0.0001 k3

										pc__reply+="${k1}${k2}${k3}"

										[[ -n "${pc__reply}" ]] || pc__reply="${pc__default}"

										case "${pc__reply^^}" in
										Y*) printf "\n" && return 0 ;;
										N*) printf "\n" && return 1 ;;
										*) printf "\e8\e[J" && pc__suggestion=1 ;;
										esac
									done
								}
							}

							{ #utiltiies
								pc__run_print_confirm() {
									pc__print_question_interactive
								}
							}

							{ #variables
								declare -i \
									pc__suggestion="${pc__suggestion:+0}" \
									pc__printed_suggestion="${pc__printed_suggestion:+0}"

								declare \
									pc__format_label="${pc__format_label:+}" \
									pc__format_prompt="${pc__format_prompt:+}"

								declare \
									pc__default="${pc__default:+}" \
									pc__yn_choice="${pc__yn_choice:+}" \
									pc__prompt="${pc__prompt:+}" \
									pc__suggestion_prompt="${pc__suggestion_prompt:+}" \
									pc__current_cursor_position="${pc__current_cursor_position:+}" \
									pc__reply="${pc__reply:+}"
							}

							{ #setting-variables

								{ # pc__default
									pc__default="off"
									((pc__default_yes)) && pc__default="Y"
									((pc__default_no)) && pc__default="N"
									((pc__default_off)) && pc__default="off"
								}

								{ # pc__yn_choice
									case "${pc__default}" in
									"Y") pc__yn_choice="Y/n" ;;
									"N") pc__yn_choice="y/N" ;;
									"off") pc__yn_choice="y/n" ;;
									esac
								}

								{ # pc__prompt
									printf -v "pc__prompt" "%s  [ %s ]" \
										"${pc__question}" "${pc__yn_choice}"
								}

								{ # pc__format_label
									printf -v "pc__format_label" "%s%s" \
										$'\e[7;5;48;5;234;38;5;226m'" WARNING "$'\e[0m' \
										$'\e[48;5;233;38;5;34m'" ❗ ${pc__label^}"$'\e[K\e[0m'
								}

								{ # pc__format_prompt
									if [[ -n "${pc__label}" ]]; then
										printf -v "pc__format_prompt" "%s" \
											$'\e[1;38;5;118m'"┊┊┊┊┊┊┊┊┊"$'\n'"░░░░░░░░░" \
											$'\e[1;38;5;226m'" ⚡ ${pc__prompt} "$'\e[0m'
									else
										printf -v "pc__format_prompt" "%s" \
											$'\e[1;38;5;226m'" ⚡ ${pc__prompt} "$'\e[0m'
									fi
								}

								{ # pc__suggestion_prompt
									printf -v "pc__suggestion_prompt" "%s" \
										$'\e[7;5;48;5;15;38;5;124m'" Enter 'Y' or 'N' (yes / no). "$'\e[0m'
								}
							}

							:

							pc__run_print_confirm
						}
					}

					{ #variables
						declare -i \
							pc__default_yes="${pc__default_yes:+0}" \
							pc__default_no="${pc__default_no:+0}" \
							pc__default_off="${pc__default_off:+0}"

						declare \
							pc__label="${pc__label:+}" \
							pc__question="${pc__question:+}"
					}

					{ #setting-variables
						config_parse_args "${@}"

						{ #options
							[[ -n "${pc__question}" ]] || pc__question="do you want to continue?"

							((pc__default_yes)) || pc__default_yes="1"

							((pc__default_no)) && pc__default_yes=0
							((pc__default_yes)) && pc__default_no=0
							((pc__default_off)) && pc__default_yes=0
						}
					}

					:

					((force)) && return 0

					pc__print_confirm
				}

				pgp__print_log_line() {
					{ #helpers
						_help() {
							cat <<-EOF
								$(printf "\e[1m%s\e[0m" "pgp__print_log_line")

								$(printf "\e[1;4m%s\e[0m" "Usage:")
								  pgp__print_log_line [--options]

								$(printf "\e[1;4m%s\e[0m" "Options:")
								  -h, --help          <boolean?>      Display this help information.
								  -l, --left-text     <string>        Set Left-Text value.
								  -r, --right-text    <string>        Set Right-Text value.

								$(printf "\e[1;4m%s\e[0m" "Examples:")
								  pgp__print_log_line -l "Downloading" -r "bash-project"

								  pgp__print_log_line \ 
								    --left-text "Downloading" \ 
								    --right-text "bash-project"

							EOF

							exit 0
						}

						config_parse_args() {
							((${#})) || _help

							while ((${#})); do
								arg="${1:-}" val="${2:-}" && shift

								case "${arg}" in
								-h | --help) _help ;;
								-l | --left-text) pll__left_text="${val:?$'\n'"$(throw_error "Option \"${arg}\" requires an argument.")"}" && shift ;;
								-r | --right-text) pll__right_text="${val:?$'\n'"$(throw_error "Option \"${arg}\" requires an argument.")"}" && shift ;;
								*) throw_error "Unknown option \"${arg}\"" ;;
								esac
							done
						}
					}

					{ #utilities
						pll__print_log_line() {
							: $((COLUMNS - ${#pll__left_text} - ${#pll__right_text} - 30))
							printf -v "pll__filler_text_line" "%${_}s"

							printf "    %s %s %s\n" \
								$'\e[48;5;233;38;5;88m'"  [    ${pll__left_text}    ]  "$'\e[0m' \
								$'\e[38;5;236m'"${pll__filler_text_line// /─}"$'\e[0m' \
								$'\e[48;5;233;38;5;226m'"  \"${pll__right_text^}\"  "$'\e[0m'
						}
					}

					{ #variables
						declare \
							pll__left_text="${pll__left_text:+}" \
							pll__right_text="${pll__right_text:+}"

						declare pll__filler_text_line="${pll__filler_text_line:+}"
					}

					{ #setting-variables
						config_parse_args "${@}"

						[[ -n "${pll__left_text}" ]] || throw_error "Option \"--left-text\" is required."
						[[ -n "${pll__right_text}" ]] || throw_error "Option \"--right-text\" is required."
					}

					:

					pll__print_log_line
				}

				pgp__normalize_path() {
					declare \
						np__arg_path="${1}" \
						np__path_output="${np__path_output:+}"

					np__normalize_path() {
						[[ "${np__arg_path:0:9}" == "../../../" ]] && {
							: "${PWD%/*}"
							: "${_%/*}"
							np__path_output="${_%/*}/${np__arg_path:9}"
							return 0
						}

						[[ "${np__arg_path:0:6}" == "../../" ]] && {
							: "${PWD%/*}"
							np__path_output="${_%/*}/${np__arg_path:6}"
							return 0
						}

						[[ "${np__arg_path:0:3}" == "../" ]] && {
							np__path_output="${PWD%/*}/${np__arg_path:3}"
							return 0
						}

						[[ "${np__arg_path:0:1}" == "~" ]] && np__path_output="${np__arg_path/\~/${HOME}}" && return 0

						[[ "${np__arg_path}" =~ ^\.[^/] ]] && np__path_output="${PWD}/${np__arg_path}" && return 0

						[[ "${np__arg_path:0:1}" == "." ]] && np__path_output="${np__arg_path/\./${PWD}}" && return 0

						[[ "${np__arg_path:0:1}" != "/" ]] && np__path_output="${PWD}/${np__arg_path}" && return 0

						[[ "${np__arg_path:0:1}" == "/" ]] && np__path_output="${np__arg_path}" && return 0
					}

					np__normalize_path

					printf "%s\n" "${np__path_output}"
				}

				pgp__validate_project() {
					{ #helpers
						_help() {
							cat <<-EOF
								$(printf "\e[1m%s\e[0m" "pgp__validate_project")

								$(printf "\e[1;4m%s\e[0m" "Usage:")
								  pgp__validate_project [--options]

								$(printf "\e[1;4m%s\e[0m" "Options:")
								  -h, --help       <boolean?>      Display this help information.
								  -p, --project    <string>        Set Project value.

								$(printf "\e[1;4m%s\e[0m" "Examples:")
								  pgp__validate_project -p "bash-project"

								  pgp__validate_project \ 
								    --project "bash-project"

							EOF

							exit 0
						}

						config_parse_args() {
							((${#})) || _help

							while ((${#})); do
								arg="${1:-}" val="${2:-}" && shift

								case "${arg}" in
								-h | --help) _help ;;
								-p | --project) vp__project="${val:?$'\n'"$(throw_error "Option \"${arg}\" requires an argument.")"}" && shift ;;
								*) throw_error "Unknown option \"${arg}\"" ;;
								esac
							done
						}
					}

					{ #utilities
						vp__validate_project() {
							for vp__select_project in "${iarr_psy_projects[@]}"; do
								[[ "${vp__select_project}" =~ ^"${vp__project}"$ ]] && return 0
							done

							throw_error "Project \"${vp__project}\" not found."
						}
					}

					{ #variables
						declare \
							vp__project="${vp__project:+}" \
							vp__select_project="${vp__select_project:+}"
					}

					{ #setting-variables
						config_parse_args "${@}"
					}

					:

					vp__validate_project
				}

				:

				set_pgp__project() {
					[[ -n "${project}" ]] || ((interactive)) || return 0
					((all || list)) && return 0

					if [[ -n "${project}" ]]; then
						pgp__project="${project}"
					else
						pgp__print_input \
							--label "Please enter the name of the project you would like to retrieve." \
							--prompt "Project" \
							--var-output "pgp__project"
					fi

					:

					[[ -n "${pgp__project}" ]] || throw_error "Option \"--project\" is required."

					for pgp__select_alias in "${!aarr_psy_projects_alias[@]}"; do
						[[ "${aarr_psy_projects_alias[${pgp__select_alias}]}" == "${pgp__project}" ]] &&
							pgp__project="${pgp__select_alias}" &&
							break
					done

					pgp__validate_project -p "${pgp__project}"
				}

				set_pgp__token() {
					((list || ssh)) && return 0

					if [[ -n "${token}" ]]; then
						pgp__token="${token}"
					elif [[ "${!PSY*}" ]]; then
						: "${!PSY*}" && pgp__token="${!_}"
					else
						pgp__print_input \
							--password \
							--label "Please enter your GitHub Token." \
							--prompt "Token" \
							--placeholder "ghp_4CEGFCeycSecc23dasd32dfds5k" \
							--var-output "pgp__token"
					fi

					:

					[[ -n "${pgp__token}" ]] || throw_error "Option \"--token\" is required."

					[[ "${pgp__token}" =~ ^ghp_[a-zA-Z0-9]+$ ]] || throw_error "Invalid GitHub Token"
				}

				set_pgp__root_password() {
					[[ -n "${root_password}" ]] || ((interactive || install)) || return 0
					((list)) && return 0

					printf "" | sudo -S cat /etc/shadow &>/dev/null && return 0

					# shellcheck disable=SC2153
					if [[ -n "${root_password}" ]]; then
						pgp__root_password="${root_password}"
					elif declare -p ROOT_PASSWORD &>/dev/null; then
						pgp__root_password="${ROOT_PASSWORD}"
					else
						pgp__print_input \
							--password \
							--label "Please enter your Root Password" \
							--prompt "Password" \
							--placeholder "P4s5w0RD" \
							--var-output "pgp__root_password"
					fi

					:

					[[ -n "${pgp__root_password}" ]] || throw_error "Option \"--root-password\" is required."

					printf "%s" "${pgp__root_password}" |
						sudo -S cat /etc/shadow &>/dev/null ||
						throw_error "Invalid Root Password"
				}

				set_pgp__ssh_key() {
					((ssh)) || return 0

					[[ -f "${pgp__path_ssh_key_file}" ]] && return 0

					{ # check ssh config
						[[ -d "${HOME}/.ssh" ]] || {
							mkdir -p "${HOME}/.ssh"
							chmod 700 "${HOME}/.ssh"
						}

						[[ -f "${HOME}/.ssh/config" ]] || {
							: >"${HOME}/.ssh/config"
							chmod 600 "${HOME}/.ssh/config"
						}

						if sed -n "\|Host github.com|Q 1" "${HOME}/.ssh/config"; then
							cat <<-'EOF' >>"${HOME}/.ssh/config"

								Host github.com
								  HostName github.com
								  User git
								  IdentityFile ~/.ssh/psy-git
								  StrictHostKeyChecking no

							EOF
						fi
					}

					{ # get ssh key
						if [[ -n "${ssh_key}" ]]; then
							pgp__ssh_key="${ssh_key}"
						else
							: $'\e[4;1;96m'"ed25519"$'\e[0;48;5;233;38;5;34m'
							pgp__print_input \
								--password \
								--label "Please enter your ${_} SSH private key content." \
								--prompt "SSH Key" \
								--placeholder "b3BlbnNzaC1rZXktdjEAAAAABG5..." \
								--var-output "pgp__ssh_key"
						fi

						if [[ -n "${pgp__ssh_key}" ]]; then
							pgp__ssh_key="$(sed -E "s|.{70}|&\n|g" <<<"${pgp__ssh_key}")"

							printf "%s\n" \
								"-----BEGIN OPENSSH PRIVATE KEY-----" \
								"${pgp__ssh_key}" \
								"-----END OPENSSH PRIVATE KEY-----" >"${pgp__path_ssh_key_file}"

							chmod 600 "${pgp__path_ssh_key_file}"
						else
							throw_error "Option \"--ssh-key\" is required."
						fi
					}

					[[ -f "${pgp__path_ssh_key_file}" ]] || throw_error "SSH key \"psy-git\" not found"
				}
			}

			{ #utilities
				pgp__run_psy_get_projects() {
					((list)) && pgp__print_all_projects

					pgp__check_core_lib_exists_or_download

					printf "\n\n"

					for pgp__select_repo in "${iarr_pgp__download_projects[@]}"; do
						pgp__select_owner="${aarr_psy_projects_owner[${pgp__select_repo}]:?}"

						pgp__download_project \
							--owner "${pgp__select_owner}" \
							--repo "${pgp__select_repo}" \
							--output "${pgp__path_psy_projects_directory}" ||
							throw_error "Failed to download project \"${pgp__select_repo}\""

						pgp__check_generate_dotenv_file

						pgp__check_install_project

						pgp__print_log_line -l "DONE" -r "${pgp__select_repo//-/ }"

						printf "\n"
					done

					printf "\n\n"
				}
			}

			{ #variables
				declare -i pgp__disable_print_info="${pgp__disable_print_info:+0}"

				declare \
					pgp__path_core_default_directory="${pgp__path_core_default_directory:+}" \
					pgp__path_psy_projects_directory="${pgp__path_psy_projects_directory:+}" \
					pgp__path_ssh_key_file="${pgp__path_ssh_key_file:+}" \
					pgp__project="${pgp__project:+}" \
					pgp__token="${pgp__token:+}" \
					pgp__root_password="${pgp__root_password:+}" \
					pgp__ssh_key="${pgp__ssh_key:+}"

				declare \
					pgp__select_alias="${pgp__select_alias:+}" \
					pgp__select_owner="${pgp__select_owner:+}" \
					pgp__select_repo="${pgp__select_repo:+}"

				declare -a iarr_pgp__download_projects
			}

			{ #setting-variables
				pgp__path_core_default_directory="${HOME}/.cache/psy/bash-projects/lib"
				pgp__path_psy_projects_directory="$(pgp__normalize_path "${directory}")"
				pgp__path_ssh_key_file="${HOME}/.ssh/psy_git"

				set_pgp__project
				set_pgp__token
				set_pgp__root_password
				set_pgp__ssh_key

				{ # iarr_pgp__download_projects
					if ((all)); then
						iarr_pgp__download_projects=("${iarr_psy_projects[@]}")
					else
						iarr_pgp__download_projects=("${pgp__project:-"psy"}")
					fi
				}

				{ #debug
					! : && printf "\e[92m%s\n" \
						$'\n' \
						$'\e[2;92m[DEBUG]\e[0;92m '"${FUNCNAME[0]^}()" \
						$'' \
						"    pgp__path_core_default_directory:    \"${pgp__path_core_default_directory}\"" \
						"    pgp__path_psy_projects_directory:    \"${pgp__path_psy_projects_directory}\"" \
						"    pgp__path_ssh_key_file:              \"${pgp__path_ssh_key_file}\"" \
						"    pgp__project:                        \"${pgp__project}\"" \
						"    pgp__token:                          \"${pgp__token}\"" \
						"    pgp__root_password:                  \"${pgp__root_password}\"" \
						"    pgp__ssh_key:                        \"${pgp__ssh_key}\"" \
						$'\e[96m\n' &&
						declare -p iarr_pgp__download_projects && printf "\e[0m\n\n"
				}
			}

			:

			pgp__run_psy_get_projects
		}
	}

	{ #variables
		declare -i \
			all="${all:+0}" \
			force="${force:+0}" \
			git="${git:+0}" \
			generate_dotenv="${generate_dotenv:+0}" \
			install="${install:+0}" \
			list="${list:+0}" \
			interactive="${interactive:+0}" \
			no_interactive="${no_interactive:+0}" \
			ssh="${ssh:+0}"

		declare \
			directory="${directory:+}" \
			ssh_key="${ssh_key:+}" \
			project="${project:+}" \
			root_password="${root_password:+}" \
			token="${token:+}"

		declare -a iarr_psy_projects

		declare -A \
			aarr_psy_projects_alias \
			aarr_psy_projects_owner
	}

	{ #setting-variables
		config_parse_args "${@}"

		{ # COLUMNS LINES
			declare -p COLUMNS LINES &>/dev/null || {
				shopt -s checkwinsize && (: && :)
				[[ -z "${COLUMNS:-}" ]] && COLUMNS=100
				[[ -z "${LINES:-}" ]] && LINES=40
			}
		}

		{ #options
			[[ -n "${directory}" ]] || directory="${HOME}/installations/psy-projects"

			if ((git)); then
				type git &>/dev/null || throw_error "Command \"git\" is required"
			else
				type curl &>/dev/null || throw_error "Command \"curl\" is required"
			fi

			((ssh)) && ! ((git)) && throw_error "Option \"--ssh\" requires \"-g | --git\""
			((ssh)) && ! type ssh &>/dev/null && throw_error "Command \"ssh\" is required"
		}

		{ # iarr_psy_projects aarr_psy_projects_{alias,owner}
			iarr_psy_projects=(
				"psy"
				"bash-core-library"
				"psy-bash-tools"
				"psy-dev-utilities"
				"bootstrap-ved"
				"virtual-env-docker"
				"psy-translator"
			)

			aarr_psy_projects_alias=(
				["bash-core-library"]="core"
				["psy-bash-tools"]="tools"
				["psy-dev-utilities"]="dev"
				["bootstrap-ved"]="boot"
				["virtual-env-docker"]="ved"
				["psy-translator"]="tra"
			)

			aarr_psy_projects_owner=(
				["psy"]="psy-projects-bash"
				["bash-core-library"]="psy-projects-bash"
				["psy-bash-tools"]="psy-projects-bash"
				["psy-dev-utilities"]="psy-projects-bash"
				["bootstrap-ved"]="psy-projects-bash"
				["virtual-env-docker"]="psy-projects-docker"
				["psy-translator"]="psy-projects-bash"
			)
		}

		{ #debug
			! : && printf "\e[92m%s\n" \
				$'\n' \
				$'\e[2;92m[DEBUG]\e[0;92m '"${FUNCNAME[0]^}()" \
				$'' \
				"    all:                \"${all}\"" \
				"    force:              \"${force}\"" \
				"    git:                \"${git}\"" \
				"    generate_dotenv:    \"${generate_dotenv}\"" \
				"    install:            \"${install}\"" \
				"    list:               \"${list}\"" \
				"    interactive:        \"${interactive}\"" \
				"    no_interactive:     \"${no_interactive}\"" \
				"    ssh:                \"${ssh}\"" \
				"    directory:          \"${directory}\"" \
				"    ssh_key:            \"${ssh_key}\"" \
				"    project:            \"${project}\"" \
				"    root_password:      \"${root_password}\"" \
				"    token:              \"${token}\"" \
				$'\e[96m\n' &&
				declare -p iarr_psy_projects && printf "\n" &&
				declare -p aarr_psy_projects_alias && printf "\n" &&
				declare -p aarr_psy_projects_owner && printf "\e[0m\n\n"
		}
	}

	:

	pgp__psy_get_projects
}

psy_get_projects "${@}" || throw_error "Failed to run \"psy_get_projects\""
