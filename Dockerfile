FROM antonikonovalov/docker-golang

ENV EJABBERD_VERSION 15.12
ENV EJABBERD_USER ejabberd
ENV EJABBERD_ROOT /opt/ejabberd
ENV PATH  $EJABBERD_ROOT/bin:$PATH
ENV DEBIAN_FRONTEND noninteractive
ENV XMPP_DOMAIN localhost

# Add ejabberd user and group
RUN groupadd -r $EJABBERD_USER \
    && useradd -r -m \
       -g $EJABBERD_USER \
       -d $EJABBERD_ROOT \
       -s /usr/sbin/nologin \
       $EJABBERD_USER
RUN sudo usermod -a -G sudo $EJABBERD_USER

# update and install tools
RUN apt-get update -y \
    && apt-get install --no-install-recommends -y -q \
        curl wget \
        build-essential ca-certificates git mercurial bzr \
        python2.7 python-jinja2 \
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
RUN git clone https://github.com/processone/ejabberd-contrib.git $EJABBERD_ROOT/ejabberd-contrib \
    && cd $EJABBERD_ROOT/ejabberd-contrib/mod_mam \
    && sh build.sh \
    && cp $EJABBERD_ROOT/ejabberd-contrib/mod_mam/ebin/*.beam $EJABBERD_ROOT/lib/ejabberd-$EJABBERD_VERSION/ebin \
    && cd $EJABBERD_ROOT/ejabberd-contrib/mod_muc_admin \
    && sh build.sh \
    && cp $EJABBERD_ROOT/ejabberd-contrib/mod_muc_admin/ebin/*.beam $EJABBERD_ROOT/lib/ejabberd-$EJABBERD_VERSION/ebin


# Wrapper for setting config on disk from environment
# allows setting things like XMPP domain at runtime
COPY ./run $EJABBERD_ROOT/bin/run

VOLUME ["$EJABBERD_ROOT/database", "$EJABBERD_ROOT/ssl"]
EXPOSE 5222 5269 5280 4560

CMD ["start"]
ENTRYPOINT ["run"]
