import Milter
import time
import sys
import os
import email
import subprocess
from Milter.utils import parse_addr
import psycopg2

db_config={}
db_config["user"] = "{{ db_user }}_spamd"
db_config["password"] = "{{ db_password }}"
db_config["database"] = "{{ db_name }}"
db_config["host"] = "localhost"

class SpamdMilter(Milter.Base):
    wantedheaders = frozenset(("X-Spam-Checker-Version", "X-Spam-Level", "X-Spam-Status"))
    db = dict()

    @Milter.noreply
    def connect(self, IPname, family, hostaddr):
        self.mail = list()
        self.to = None
        return Milter.CONTINUE

    @Milter.noreply
    def envfrom(self, mailfrom, *str):
        user_from, domain_from = parse_addr(mailfrom)
        user_from = user_from.split("+", 1)[0]
        mail_from = "@".join((user_from, domain_from))
        self.mail.append("From %s %s\n" % (mail_from, time.ctime()))
        return Milter.CONTINUE

    def envrcpt(self, to, *str):
        if not self.to:
            self.to = "@".join(parse_addr(to))
            return Milter.CONTINUE
        else:
            return Milter.TEMPFAIL

    @Milter.noreply
    def header(self, name, hval):
        self.mail.append("%s: %s\n" % (name, hval))
        return Milter.CONTINUE

    @Milter.noreply
    def eoh(self):
        self.mail.append("\n")
        return Milter.CONTINUE

    @Milter.noreply
    def body(self, chunk):
        self.mail.append(chunk)
        return Milter.CONTINUE

    def eom(self):
        mail = "".join(self.mail)
        user = self.lookup_user()
        spamc = subprocess.Popen(["/usr/bin/spamc", "-E", "--headers", "-u", user], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        spamd_output, _ = spamc.communicate(mail)
        if spamc.returncode == 1:
            return Milter.REJECT
        msg_post_scan = email.message_from_string(spamd_output)
        for header, value in msg_post_scan.items():
            if header in self.wantedheaders:
                self.addheader(header, value)
        self.addheader("X-Rcpt-To", self.to)
        self.addheader("X-SpamMilter", "Filtered for <%s>" % user)
        return Milter.ACCEPT

    def lookup_user(self):
        user = "DEFAULT"
        for _ in range(2):
            try:
                self.db["cursor"].execute("SELECT DISTINCT spamuser FROM find_user_address(%s) LIMIT 1", (self.to,))
                if self.db["cursor"].rowcount > 0:
                    user = self.db["cursor"].fetchall()[0][0]
                return user
            except:
                if self.db["connection"].closed > 0:
                    try:
                        self.db["connection"] = psycopg2.connect(**self.db["config"])
                        self.db["connection"].autocommit = True
                        self.db["cursor"] = self.db["connection"].cursor()
                    except:
                        break
        return user


if __name__ == "__main__":
    os.umask(0007)
    socketname = "/var/spool/postfix/run/spammilter.sock"
    timeout = 600
    SpamdMilter.db["config"] = db_config
    SpamdMilter.db["connection"] = psycopg2.connect(**SpamdMilter.db["config"])
    SpamdMilter.db["connection"].autocommit = True
    SpamdMilter.db["cursor"] = SpamdMilter.db["connection"].cursor()
    Milter.factory = SpamdMilter
    Milter.set_flags(Milter.ADDHDRS)
    Milter.runmilter("SpamdMilter",socketname,timeout)
