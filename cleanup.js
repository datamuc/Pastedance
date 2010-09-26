db.Pastedance.remove({
    $where: function() {
        now = (new Date).getTime() / 1000;
        if(this.time == -1) {
            return false
        } else {
            return this.time + this.expires < now
        }
    }
});
