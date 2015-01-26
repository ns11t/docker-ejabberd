FROM google/debian:wheezy
MAINTAINER Anton Konovalov

ENV EJABBERD_VERSION 14.12
ENV EJABBERD_USER ejabberd
ENV EJABBERD_ROOT /opt/ejabberd
ENV HOME $EJABBERD_ROOT
ENV PATH $EJABBERD_ROOT/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV DEBIAN_FRONTEND noninteractive
ENV XMPP_DOMAIN localhost

# Add ejabberd user and group
RUN groupadd -r $EJABBERD_USER \
    && useradd -r -m \
       -g $EJABBERD_USER \
       -d $EJABBERD_ROOT \
       -s /usr/sbin/nologin \
       $EJABBERD_USER
# set erlang 
RUN wget -q -O /tmp/erlang-solutions_1.0_all.deb https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb \
    && chmod +x /tmp/erlang-solutions_1.0_all.deb \
    && dpkg -i /tmp/erlang-solutions_1.0_all.deb

# update and install tools
RUN apt-get update -y \
    && apt-get install --no-install-recommends -y -q \
        curl \
        build-essential ca-certificates git mercurial bzr \
        python2.7 python-jinja2 erlang \
    && rm -rf /var/lib/apt/lists/*
    
# Install as user
USER $EJABBERD_USER
# Install ejabberd
RUN wget -q -O /tmp/ejabberd-installer.run "http://www.process-one.net/downloads/downloads-action.php?file=/ejabberd/$EJABBERD_VERSION/ejabberd-$EJABBERD_VERSION-linux-x86_64-installer.run" \
    && chmod +x /tmp/ejabberd-installer.run \
    && /tmp/ejabberd-installer.run \
            --mode unattended \
            --prefix $EJABBERD_ROOT \
            --adminpw ejabberd \
    && rm -rf /tmp/* \
    && mkdir $EJABBERD_ROOT/ssl \
    && rm -rf $EJABBERD_ROOT/database/ejabberd@localhost

# Make config
COPY ejabberd.yml.tpl $EJABBERD_ROOT/conf/ejabberd.yml.tpl
COPY ejabberdctl.cfg.tpl $EJABBERD_ROOT/conf/ejabberdctl.cfg.tpl
RUN sed -i "s/ejabberd.cfg/ejabberd.yml/" $EJABBERD_ROOT/bin/ejabberdctl \
    && sed -i "s/root/$EJABBERD_USER/g" $EJABBERD_ROOT/bin/ejabberdctl

# Make mod_muc_admin
RUN git clone https://github.com/processone/ejabberd-contrib.git /opt/ejabberd-contrib \
    && ./opt/ejabberd-contrib/mod_muc_admin/build.sh \
    && cp /opt/ejabberd-contrib/mod_muc_admin/ebin/*.beam $EJABBERD_ROOT/lib/ejabberd-$EJABBERD_VERSION/ebin/
# Wrapper for setting config on disk from environment
# allows setting things like XMPP domain at runtime
COPY ./run $EJABBERD_ROOT/bin/run

VOLUME ["$EJABBERD_ROOT/database", "$EJABBERD_ROOT/ssl"]
EXPOSE 5222 5269 5280 4560

CMD ["start"]
ENTRYPOINT ["run"]
