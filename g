#!/usr/bin/env bash

# NOTE: fzf -m to allow multi select.

# Default limit is 30, we usually have 50-100 open at a time.
max_open_prs_to_fetch=9999
# TODO: We should fix this in Jira to actually match up properly.
jira_statuses="OPEN\nIN PROGRESS\nIN REVIEW\nQA VERIFICATION\nCLOSED"

# GitHub

check_pr_ci_status() {
	pr="$1"
	if [ -z "$pr" ]; then
		pr="$(gh pr list -L $max_open_prs_to_fetch | fzf --reverse | cut -f 1)"
	fi
	gh pr checks "$pr"
}

view_open_pr() {
	pr="$(gh pr list -L $max_open_prs_to_fetch | fzf --reverse | cut -f 1)"
	gh pr view "$pr"
	check_pr_ci_status "$pr"
}

checkout_pr() {
	gh pr view "$(gh pr list -L $max_open_prs_to_fetch | fzf --reverse | cut -f 1)"
}

create_pr() {
	gh pr create
}

list_my_open_prs() {
	gh pr list -L "$max_open_prs_to_fetch" --search "is:open author:@me"
}

show_github_options() {
	actions="View Open PRs\nCheckout\nCreate\nCheck CI Status\nList My Open PRs"
	command="$(echo -e "$actions" | fzf --reverse --prompt 'Select PR action:')"

	case "$command" in
		"View Open PRs")
			view_open_pr
			;;
		"Checkout")
			checkout_pr
			;;
		"Create")
			create_pr
			;;
		"Check CI Status")
			check_pr_ci_status
			;;
		"List My Open PRs")
			list_my_open_prs
			;;

	esac
}

# Jira

select_jira_ticket() {
	status="$1"

	if [ -z "$status" ]; then
		status="$(echo -e "${jira_statuses}""\nALL" | fzf --reverse --prompt 'Search for ticket in status:')"
	fi

	if [ "$status" = "ALL" ]; then
		# Searching for no status text will search all statuses.
		status=""
	fi

	jira ls -S "$status" | fzf --reverse | cut -d ':' -f1
}

view_jira_ticket_transitions() {
	ticket="$1"
	if [ -z "$ticket" ]; then
		echo "No ticket provided when looking for valid transition states"
		exit 1
	fi
	jira transitions "$ticket" | cut -d ' ' -f 2-
}

view_jira_ticket_details() {
	jira view "$(select_jira_ticket)"
}

open_jira_ticket_in_browser() {
	# Redirecting all output because browser noise.
	jira browse "$(select_jira_ticket)" > /dev/null 2>&1
}

start_jira_ticket() {
	jira start "$(select_jira_ticket "OPEN")"
}

transition_jira_ticket() {
	# jira transition --noedit -o "priority:Medium" "Ready for Review" WCO-1271
	ticket="$(select_jira_ticket "ALL")"
	state="$(view_jira_ticket_transitions "$ticket" | fzf --reverse --prompt 'Select New Ticket State:')"
	# Priority is required to be set when transitioning, Medium is default in the web UI.
	jira transition --noedit -o "priority:Medium" "$state" "$ticket"
}

add_comment_to_jira_ticket() {
	jira comment "$(select_jira_ticket)"
}

show_jira_options() {
	actions="View Ticket Details\nOpen In Browser\nStart Ticket\nTransition To State\nAdd Comment"
	command="$(echo -e "$actions" | fzf --reverse --prompt 'Select Jira ticket action: ')"

	case "$command" in
		"View Ticket Details")
			view_jira_ticket_details
			;;
		"Open In Browser")
			open_jira_ticket_in_browser
			;;
		"Start Ticket")
			start_jira_ticket
			;;
		"Transition To State")
			transition_jira_ticket
			;;
		"Add Comment")
			add_comment_to_jira_ticket
			;;
	esac
}

actions="PRs\nJira Tickets\nGit"
command="$(echo -e "$actions" | fzf --reverse --prompt 'Choose an action:')"

case "$command" in
	"PRs")
		show_github_options
		;;
	"Jira Tickets")
		show_jira_options
		;;
	"Git")
		# TODO: check ~/tool.md
		echo "Got Git"
		;;
esac

