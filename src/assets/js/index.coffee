$ ->
    $('#import input[type="text"]').focus ->
        self = $(this)
        if self.hasClass 'default'
            self.val ''
            self.removeClass 'default'
            
    $('#import').submit ->
        $('#import input[type="submit"]').replaceWith '<span>Loading...</span>'
