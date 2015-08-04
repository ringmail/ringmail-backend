function select_reg(sel)
{
	if (sel == 'email')
	{
		$('#check-email').prop('checked', true);
		$('#check-domain').prop('checked', false);
		$('#email_1').prop('disabled', false);
		$('#domain_2').prop('disabled', true);
		$('#email_2').prop('disabled', true);
	}
	else if (sel == 'domain')
	{
		$('#check-email').prop('checked', false);
		$('#check-domain').prop('checked', true);
		$('#email_1').prop('disabled', true);
		$('#domain_2').prop('disabled', false);
		$('#email_2').prop('disabled', false);
	}
}

