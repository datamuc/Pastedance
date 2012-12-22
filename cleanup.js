db.Pastedance.remove({$where: function() {
        var now = parseInt((new Date).getTime() / 1000);
        if (this.expires == "-1") {
            return false;
        } else {
            return this.time + parseInt(this.expires)  <  now;
        }
    }
});
